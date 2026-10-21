#!/usr/bin/env python3
"""Write NVMe SMART and LVM thin-pool figures for node-exporter's textfile collector.

Observability plan, Phase 5.5.1. Installed on the Proxmox host by
playbooks/infrastructure/proxmox-exporter-setup.yml and run every 15 minutes by a systemd timer.
The alerts that read these series are in prometheus/alerts/capacity.yml.

Output (atomic: written aside, then renamed), for each NVMe device:
  smart_nvme_info{device, model}                       1
  smart_nvme_scrape_success{device}                    1 if smartctl answered, else 0
  smart_nvme_scrape_timestamp_seconds{device}          when it last answered
  smart_nvme_percentage_used{device}                   rated life consumed, 0-100 (can pass 100)
  smart_nvme_available_spare_percent{device}
  smart_nvme_available_spare_threshold_percent{device}
  smart_nvme_critical_warning{device}                  bit flags, 0 is healthy
  smart_nvme_temperature_celsius{device}
  smart_nvme_media_errors{device}                      counter value as reported
  smart_nvme_unsafe_shutdowns{device}                  counter: each is an unclean power loss
  smart_nvme_power_cycles{device}, smart_nvme_power_on_seconds_total{device}
  smart_nvme_data_written_bytes_total{device}          Data Units Written * 512000
  smart_nvme_data_read_bytes_total{device}
and for each LVM thin pool:
  lvm_thin_pool_data_percent{vg, lv}, lvm_thin_pool_metadata_percent{vg, lv}

Environment: NVME_DEVICES (space separated, default /dev/nvme0), TEXTFILE (output path, default
/var/lib/node_exporter/textfile_collector/nvme_smart.prom).
"""
import json
import os
import subprocess
import sys
import time

UNIT_BYTES = 512_000  # NVMe "data unit" = 1000 * 512 bytes
HEALTH_LOG = "nvme_smart_health_information_log"


# Every series this script writes, with its type and help text (promtool check metrics wants both).
META = {
    "smart_nvme_info": ("gauge", "NVMe model (always 1)."),
    "smart_nvme_scrape_success": ("gauge", "1 if smartctl answered for the device, else 0."),
    "smart_nvme_scrape_timestamp_seconds": ("gauge", "Unix time smartctl last answered for the device."),
    "smart_nvme_percentage_used": ("gauge", "Rated NVMe life consumed in percent (can pass 100)."),
    "smart_nvme_available_spare_percent": ("gauge", "Spare blocks left, in percent."),
    "smart_nvme_available_spare_threshold_percent": ("gauge", "Spare percentage at which the drive is failing."),
    "smart_nvme_critical_warning": ("gauge", "Critical warning bit flags, 0 is healthy."),
    "smart_nvme_temperature_celsius": ("gauge", "Composite drive temperature."),
    "smart_nvme_media_errors": ("gauge", "Media and data integrity errors counted by the drive."),
    "smart_nvme_unsafe_shutdowns": ("gauge", "Unsafe shutdowns counted by the drive: each is an unclean power loss."),
    "smart_nvme_power_cycles": ("gauge", "Power cycles counted by the drive."),
    "smart_nvme_power_on_seconds_total": ("counter", "Time the drive has been powered on."),
    "smart_nvme_data_written_bytes_total": ("counter", "Bytes written to the drive (data units written * 512000)."),
    "smart_nvme_data_read_bytes_total": ("counter", "Bytes read from the drive (data units read * 512000)."),
    "lvm_thin_pool_data_percent": ("gauge", "Real data space used in an LVM thin pool, in percent."),
    "lvm_thin_pool_metadata_percent": ("gauge", "Metadata space used in an LVM thin pool, in percent."),
}


def esc(value):
    return str(value).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")


def line(name, labels, value):
    lab = ",".join(f'{k}="{esc(v)}"' for k, v in labels.items())
    return f"{name}{{{lab}}} {value}" if lab else f"{name} {value}"


def smart_lines(device, data, now):
    """Lines for one device from `smartctl -j -a` output; the failure line when it did not answer."""
    name = os.path.basename(device)
    status = (data.get("smartctl") or {}).get("exit_status", 0)
    log = data.get(HEALTH_LOG)
    # Bits 0-2 of smartctl's exit status are command, open and SMART-command failures.
    if not isinstance(log, dict) or (isinstance(status, int) and status & 7):
        return [line("smart_nvme_scrape_success", {"device": name}, 0)]

    d = {"device": name}
    out = [
        line("smart_nvme_info", {"device": name, "model": data.get("model_name", "unknown")}, 1),
        line("smart_nvme_scrape_success", d, 1),
        line("smart_nvme_scrape_timestamp_seconds", d, int(now)),
    ]
    gauges = [
        ("smart_nvme_percentage_used", "percentage_used"),
        ("smart_nvme_available_spare_percent", "available_spare"),
        ("smart_nvme_available_spare_threshold_percent", "available_spare_threshold"),
        ("smart_nvme_critical_warning", "critical_warning"),
        ("smart_nvme_media_errors", "media_errors"),
        ("smart_nvme_unsafe_shutdowns", "unsafe_shutdowns"),
        ("smart_nvme_power_cycles", "power_cycles"),
    ]
    for metric, key in gauges:
        if isinstance(log.get(key), (int, float)):
            out.append(line(metric, d, log[key]))
    if isinstance(log.get("power_on_hours"), (int, float)):
        out.append(line("smart_nvme_power_on_seconds_total", d, int(log["power_on_hours"]) * 3600))
    if isinstance(log.get("temperature"), (int, float)):
        out.append(line("smart_nvme_temperature_celsius", d, log["temperature"]))
    for metric, key in (("smart_nvme_data_written_bytes_total", "data_units_written"), ("smart_nvme_data_read_bytes_total", "data_units_read")):
        if isinstance(log.get(key), (int, float)):
            out.append(line(metric, d, int(log[key]) * UNIT_BYTES))
    return out


def lvm_lines(report):
    """Lines for every thin pool in `lvs --reportformat json` output."""
    out = []
    for rep in (report or {}).get("report", []):
        for lv in rep.get("lv", []):
            # lv_attr starts with `t` for a thin pool.
            if not str(lv.get("lv_attr", "")).startswith("t"):
                continue
            labels = {"vg": lv.get("vg_name", ""), "lv": lv.get("lv_name", "")}
            for metric, key in (("lvm_thin_pool_data_percent", "data_percent"), ("lvm_thin_pool_metadata_percent", "metadata_percent")):
                try:
                    out.append(line(metric, labels, float(lv[key])))
                except (KeyError, ValueError):
                    pass
    return out


def render(smart, lvm, now):
    """`smart` is {device path: parsed smartctl JSON or None}; `lvm` the parsed lvs JSON or None."""
    series = []
    for device, data in smart.items():
        series.extend(smart_lines(device, data, now) if data else [line("smart_nvme_scrape_success", {"device": os.path.basename(device)}, 0)])
    series.extend(lvm_lines(lvm))
    # Group by metric so each family has one HELP and TYPE, as the text format wants.
    out, seen = [], []
    for name in META:
        rows = [l for l in series if l.split("{", 1)[0].split(" ", 1)[0] == name]
        if rows:
            out.append(f"# HELP {name} {META[name][1]}")
            out.append(f"# TYPE {name} {META[name][0]}")
            out.extend(rows)
    return "\n".join(out) + "\n"


def run_json(cmd):
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return json.loads(res.stdout)
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return None


def main():
    devices = os.environ.get("NVME_DEVICES", "/dev/nvme0").split()
    target = os.environ.get("TEXTFILE", "/var/lib/node_exporter/textfile_collector/nvme_smart.prom")
    smart = {d: run_json(["smartctl", "-j", "-a", d]) for d in devices}
    lvm = run_json(["lvs", "--reportformat", "json", "--units", "b", "-o", "lv_name,vg_name,lv_attr,data_percent,metadata_percent"])
    text = render(smart, lvm, time.time())
    tmp = os.path.join(os.path.dirname(target), "." + os.path.basename(target) + f".{os.getpid()}")
    with open(tmp, "w") as fh:
        fh.write(text)
    os.chmod(tmp, 0o644)
    os.replace(tmp, target)
    # Exit non-zero when no device answered, so the unit shows as failed.
    if not any(d and not (d.get("smartctl") or {}).get("exit_status", 0) & 7 and isinstance(d.get(HEALTH_LOG), dict) for d in smart.values()):
        print("no NVMe device answered smartctl", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
