# 🛗 Debug Elevators

A flexible, lightweight **elevator system** designed to work with **QBCore**, **ESX**, or **Standalone** servers — no dependencies required beyond your targeting resource and [ox_lib](https://github.com/overextended/ox_lib).

Supports:
- ✅ Framework auto-detection (`qb-core`, `es_extended`, or standalone)
- ✅ Per-floor job locks via `groups`
- ✅ ox_target / qb-target / qtarget support
- ✅ ox_lib context menus and notifications
- ✅ Clean fade-in/out teleport transitions

---

## ⚙️ Features

- Works seamlessly across **QBCore**, **ESX**, and **Standalone**
- Each elevator and floor has customizable:
  - **Title & Description**
  - **Coordinates & Heading**
  - **Target zone size**
  - **Job restrictions** (via `groups`)
- **Standalone servers** automatically skip job-locks
- Player feedback via **ox_lib notifications** (not F8 spam)

---

## 📁 Installation

1. **Drag & drop** the `debug_elevators` folder into your `resources` directory.

2. Add this to your server config:
   ```bash
   ensure debug_elevators
