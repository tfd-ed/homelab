"""Tests for nvme-smart-metrics.py. Run: python3 -m unittest -v test_nvme_smart_metrics (from this directory)."""
import importlib.util
import os
import unittest

spec = importlib.util.spec_from_file_location("nsm", os.path.join(os.path.dirname(__file__), "nvme-smart-metrics.py"))
nsm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nsm)

# Shape of `smartctl -j -a /dev/nvme0` (smartctl 7.x) for an NVMe drive, trimmed.
GOOD = {
    "smartctl": {"exit_status": 0},
    "model_name": 'Samsung "980" PRO 1TB',
    "nvme_smart_health_information_log": {
        "critical_warning": 0, "temperature": 47, "available_spare": 100, "available_spare_threshold": 10,
        "percentage_used": 3, "data_units_read": 4_000_000, "data_units_written": 2_500_000,
        "power_cycles": 34, "power_on_hours": 1500, "unsafe_shutdowns": 12, "media_errors": 0,
    },
}
LVS = {"report": [{"lv": [
    {"lv_name": "data", "vg_name": "pve", "lv_attr": "twi-aotz--", "data_percent": "41.50", "metadata_percent": "3.20"},
    {"lv_name": "root", "vg_name": "pve", "lv_attr": "-wi-ao----", "data_percent": "", "metadata_percent": ""},
    {"lv_name": "vm-100-disk-0", "vg_name": "pve", "lv_attr": "Vwi-aotz--", "data_percent": "12.00", "metadata_percent": ""},
]}]}


def metrics(text):
    return {l.rsplit(" ", 1)[0]: l.rsplit(" ", 1)[1] for l in text.splitlines() if l and not l.startswith("#")}


class SmartTest(unittest.TestCase):
    def test_a_healthy_drive_is_reported_in_full(self):
        m = metrics(nsm.render({"/dev/nvme0": GOOD}, None, 1_000_000))
        self.assertEqual(m['smart_nvme_percentage_used{device="nvme0"}'], "3")
        self.assertEqual(m['smart_nvme_available_spare_percent{device="nvme0"}'], "100")
        self.assertEqual(m['smart_nvme_critical_warning{device="nvme0"}'], "0")
        self.assertEqual(m['smart_nvme_temperature_celsius{device="nvme0"}'], "47")
        self.assertEqual(m['smart_nvme_unsafe_shutdowns{device="nvme0"}'], "12")
        self.assertEqual(m['smart_nvme_scrape_success{device="nvme0"}'], "1")
        self.assertEqual(m['smart_nvme_scrape_timestamp_seconds{device="nvme0"}'], "1000000")

    def test_data_units_become_bytes(self):
        m = metrics(nsm.render({"/dev/nvme0": GOOD}, None, 0))
        self.assertEqual(m['smart_nvme_data_written_bytes_total{device="nvme0"}'], str(2_500_000 * 512_000))
        self.assertEqual(m['smart_nvme_data_read_bytes_total{device="nvme0"}'], str(4_000_000 * 512_000))

    def test_the_model_is_escaped_in_its_label(self):
        text = nsm.render({"/dev/nvme0": GOOD}, None, 0)
        self.assertIn('smart_nvme_info{device="nvme0",model="Samsung \\"980\\" PRO 1TB"} 1', text)

    def test_a_drive_that_did_not_answer_only_reports_failure(self):
        for data in (None, {}, {"smartctl": {"exit_status": 2}, **{k: v for k, v in GOOD.items() if k != "smartctl"}}):
            m = metrics(nsm.render({"/dev/nvme0": data}, None, 5))
            self.assertEqual(m, {'smart_nvme_scrape_success{device="nvme0"}': "0"})

    def test_health_flags_in_the_exit_status_are_still_a_reading(self):
        # Bit 3 and above (for example "SMART status is failing" or "error log has entries") mean the
        # drive answered: its figures are exactly what the alerts need.
        data = {**GOOD, "smartctl": {"exit_status": 8}}
        m = metrics(nsm.render({"/dev/nvme0": data}, None, 5))
        self.assertEqual(m['smart_nvme_scrape_success{device="nvme0"}'], "1")

    def test_a_missing_field_is_left_out_not_zeroed(self):
        log = dict(GOOD["nvme_smart_health_information_log"])
        del log["percentage_used"]
        m = metrics(nsm.render({"/dev/nvme0": {**GOOD, "nvme_smart_health_information_log": log}}, None, 5))
        self.assertNotIn('smart_nvme_percentage_used{device="nvme0"}', m)
        self.assertIn('smart_nvme_temperature_celsius{device="nvme0"}', m)

    def test_two_drives_get_their_own_series(self):
        m = metrics(nsm.render({"/dev/nvme0": GOOD, "/dev/nvme1": GOOD}, None, 5))
        self.assertIn('smart_nvme_percentage_used{device="nvme1"}', m)


class LvmTest(unittest.TestCase):
    def test_only_thin_pools_are_reported(self):
        m = metrics(nsm.render({}, LVS, 0))
        self.assertEqual(m['lvm_thin_pool_data_percent{vg="pve",lv="data"}'], "41.5")
        self.assertEqual(m['lvm_thin_pool_metadata_percent{vg="pve",lv="data"}'], "3.2")
        self.assertEqual([k for k in m if k.startswith("lvm_")].__len__(), 2)

    def test_no_lvm_gives_no_lvm_series(self):
        for report in (None, {}, {"report": []}):
            self.assertEqual([k for k in metrics(nsm.render({}, report, 0)) if k.startswith("lvm_")], [])


if __name__ == "__main__":
    unittest.main()
