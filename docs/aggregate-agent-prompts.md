# Aggregate Agent — Example Prompts

Routing is done by the **Classify Intent** node using regex — no LLM call.
The matched intent determines which API is fetched and what focused prompt is sent to Ollama.

---

## 🌡️ `temp` — Temperature check

**Trigger keywords:** `temp`, `hot`, `heat`, `cool`, `overh`, `burn`, `thermal`, `degree`, `°`

| Message | Matched by |
|---|---|
| `is anything getting hot?` | `hot` |
| `check the temperature` | `temp` |
| `is it overheating?` | `overh` |
| `how hot is the cpu?` | `hot` |
| `thermal status` | `thermal` |
| `any burning smell lol` | `burn` |

**Ollama prompt template:**
```
Proxmox temperature report. Respond in exactly 3 lines, no extra text:
CPU: 47.0°C [OK] | GPU: 38.0°C | NVMe: 33.0°C [OK]
Status: <one word — Normal, Warm, or Critical>
Note: <one sentence max 12 words on the above temperatures only>
```

**Expected response:**
```
CPU: 47.0°C [OK] | GPU: 38.0°C | NVMe: 33.0°C [OK]
Status: Normal
Note: All components are running well within safe temperature limits.
```

---

## 💻 `cpu` — CPU usage

**Trigger keywords:** `cpu`, `processor`, `load`, `compute`, `utiliz`, `usage cpu`, `cpu usage`

| Message | Matched by |
|---|---|
| `how's the cpu doing?` | `cpu` |
| `check cpu usage` | `cpu` |
| `what's the load average?` | `load` |
| `is the processor busy?` | `processor` |
| `cpu utilization?` | `utiliz` |

**Ollama prompt template:**
```
Proxmox CPU report. Respond in exactly 3 lines, no extra text:
CPU: 3.6% [OK] | Load avg: 0.42, 0.46, 0.43
Status: <one word — Normal, High, or Critical>
Note: <one sentence max 12 words on the above CPU data only>
```

**Expected response:**
```
CPU: 3.6% [OK] | Load avg: 0.42, 0.46, 0.43
Status: Normal
Note: CPU load is very low with stable average across all intervals.
```

---

## 🧠 `memory` — RAM / Swap

**Trigger keywords:** `mem`, `ram`, `swap`, `heap`, `out of memory`, `oom`

| Message | Matched by |
|---|---|
| `check memory usage` | `mem` |
| `how much ram is free?` | `ram` |
| `is swap being used?` | `swap` |
| `running out of memory?` | `mem` |
| `oom killer fired?` | `oom` |

**Ollama prompt template:**
```
Proxmox memory report. Respond in exactly 3 lines, no extra text:
RAM: 34.7 GB / 59.8 GB (58.1%) [OK] | Swap: 0.0%
Status: <one word — Normal, High, or Critical>
Note: <one sentence max 12 words on the above memory data only>
```

**Expected response:**
```
RAM: 34.7 GB / 59.8 GB (58.1%) [OK] | Swap: 0.0%
Status: Normal
Note: Memory usage is moderate with no swap pressure detected.
```

---

## 💾 `disk` — Storage / Disk usage

**Trigger keywords:** `disk`, `storage`, `space`, `volume`, `lvm`, `partition`, `full`, `free space`

| Message | Matched by |
|---|---|
| `check disk space` | `disk` / `space` |
| `how full is storage?` | `storage` / `full` |
| `is local-lvm getting full?` | `lvm` / `full` |
| `any partition about to fill up?` | `partition` |
| `free space on nvme?` | `space` |

**Ollama prompt template:**
```
Proxmox disk usage report. Respond in exactly 3 lines, no extra text:
local (dir): 9.8% used, 80.0 GB free [OK]
local-lvm (lvmthin): 18.5% used, 647.1 GB free [OK]
Status: <one word — Normal, High, or Critical>
Note: <one sentence max 12 words on the above disk data only>
```

**Expected response:**
```
local (dir): 9.8% used, 80.0 GB free [OK]
local-lvm (lvmthin): 18.5% used, 647.1 GB free [OK]
Status: Normal
Note: Both storage pools have ample free space available.
```

---

## 📊 `full` — Full status report (default)

**Trigger:** anything that does not match the above keywords, or `/status`

| Message | Why |
|---|---|
| `status` | no keyword match → fallback |
| `how is everything?` | no keyword match |
| `give me a report` | no keyword match |
| `/status` | command → no keyword match |
| `hello` | no keyword match |

**Ollama prompt template:**
```
Proxmox full status report. Use ONLY the data below. Output strictly in this format, no extra lines:
*Proxmox* | uptime: 4.9d
CPU: 3.6% [OK] | RAM: 58.1% [OK] | Root: 9.8% [OK]
Temp: CPU 47.0°C [OK] | GPU 38.0°C | NVMe 33.0°C [OK]
Storage:
- local (dir): 9.8% used, 80.0 GB free [OK]
- local-lvm (lvmthin): 18.5% used, 647.1 GB free [OK]
Warnings: None
Note: <one sentence, max 15 words, based only on the data above>
```

**Expected response:**
```
*Proxmox* | uptime: 4.9d
CPU: 3.6% [OK] | RAM: 58.1% [OK] | Root: 9.8% [OK]
Temp: CPU 47.0°C [OK] | GPU 38.0°C | NVMe 33.0°C [OK]
Storage:
- local (dir): 9.8% used, 80.0 GB free [OK]
- local-lvm (lvmthin): 18.5% used, 647.1 GB free [OK]
Warnings: None
Note: System is healthy with low utilization and cool temperatures.
```

---

## Status label thresholds (computed in JS, not by LLM)

| Metric | WARN | CRIT |
|---|---|---|
| CPU % | ≥ 80% | ≥ 95% |
| RAM % | ≥ 85% | ≥ 95% |
| Root disk % | ≥ 80% | ≥ 90% |
| Storage pool % | ≥ 80% | ≥ 90% |
| CPU temp | ≥ 85°C | ≥ 95°C |
| NVMe temp | ≥ 70°C | ≥ 80°C |
