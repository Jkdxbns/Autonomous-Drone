# Resources: MPU6050 Flight Controller, Filtering, and PID Control

Last updated: 2025-10-26

This document gathers the exact concepts used in `src/main.cpp` and authoritative references to learn each topic in depth: datasheets, register maps, sensor fusion (Mahony/Complementary), digital filtering, cascaded PID control for multirotors, autotuning, I²C timing/interrupts/FIFO, and practical tuning.

---

## Learning notes (moved from code)

What this program demonstrates
- Configure an MPU6050 IMU over I2C and read accel/gyro at a fixed rate.
- Run a Mahony attitude filter (6‑DoF, gyro+accel) for excellent roll/pitch.
- Use a cascaded control structure: Angle PID (outer) → Rate PID (inner).
- Mix the controller outputs into four motor PWM values.

Key MPU6050 configuration concepts
- Full‑Scale Ranges (FS):
   - Gyro FS_SEL=1 → ±500 °/s, sensitivity 65.5 LSB/(°/s)
   - Accel AFS_SEL=1 → ±4 g, sensitivity 8192 LSB/g
- DLPF (CONFIG/DLPF_CFG):
   - We use DLPF_CFG=3 → ≈44 Hz bandwidth. Group delay ~4–5 ms.
   - Lower cutoff → cleaner but more delay; higher cutoff → snappier but noisier.
- SMPLRT_DIV (with DLPF on, internal rate is 1 kHz):
   - Output rate = 1000 / (1 + DIV). We use DIV=9 → 100 Hz.
   - Example: DIV=4 → 200 Hz; DIV=0 → 1000 Hz.
- DATA_READY interrupt and FIFO:
   - New-sample interrupt reduces jitter; FIFO enables burst reads and avoids loss.

Calibration
- Gyro bias: average stationary samples and subtract constantly.
- Accel offset: optional (e.g., 6‑face) to reduce tilt bias; flat Z‑up variant included.

Attitude estimation choices (gyro + accel only)
- Complementary Filter: angle = α(angle + gyro·dt) + (1−α)·accAngle
   - Pros: tiny CPU, robust roll/pitch; Cons: tune α, yaw drifts.
- Mahony (used): quaternion + PI feedback on gravity error.
   - Pros: excellent roll/pitch, online gyro‑bias rejection; modest CPU.
- Madgwick: gradient‑descent alternative, also good; needs gain tuning.
- EKF/DCM: powerful but complex; unnecessary for strong roll/pitch performance.

Why Mahony here
- Precise roll/pitch under modest acceleration, integral bias rejection, lightweight.

Control architecture (cascaded)
- Angle PID (outer): desired angle vs estimated angle → desired angular rate.
- Rate PID (inner): desired rate vs gyro rate → torque command. D‑term on gyro; low‑pass it (PT1/notch).
- Mixer: converts roll/pitch/yaw efforts + throttle into 4 motor PWMs.

Digital filters you will encounter
- DLPF (inside MPU): we chose 44 Hz.
- PT1 Low‑Pass (1st order): y += α(x − y). Used for D‑term smoothing.
- EMA: discrete‑time PT1 equivalent; very cheap IIR smoothing.
- Notch filter: attenuates a narrow vibration band (e.g., motor/prop RPM).
- Sensor‑fusion filters: Complementary, Mahony, Madgwick, EKF.

Tuning hints (quick start)
1) Verify clean sensors (no clipping), DLPF=44 Hz; consider 94 Hz if well‑mounted.
2) Gyro bias calibration at boot. Keep the quad still.
3) Angle PID: small Kp to generate reasonable rate demands; no D.
4) Rate PID: raise Kp for crisp response, add D to suppress overshoot, small Ki for steady‑state. Low‑pass D input.
5) Increase loop rate (200–500 Hz) when wiring/timing allows; then use DATA_READY and FIFO for minimal jitter/loss.

Equations (reference)
- Complementary: θ = α(θ + ω·dt) + (1−α)·atan2(acc_y, acc_z)
- Mahony core: quaternion q updated by gyro (rad/s) with feedback proportional (Kp) and integral (Ki) to cross‑product error between measured gravity (acc) and gravity from q.
- PID (rate loop): u = Kp·e + Ki·∫e dt + Kd·(d/dt of measured rate)

Suggested reading
- Feedback and control fundamentals:
   - "Feedback Systems" — Åström & Murray (free online PDF)
   - "Feedback Control of Dynamic Systems" — Franklin, Powell, Emami‑Naeini
   - "Small Unmanned Aircraft: Theory and Practice" — Beard & McLain
- Sensor fusion and IMU topics:
   - Welch & Bishop, "An Introduction to the Kalman Filter"
   - Madgwick, "An efficient orientation filter for IMUs" (paper + code)
   - Mahony et al., "Nonlinear complementary filters on SO(3)"
- Practical filtering:
   - Richard Lyons, "Understanding Digital Signal Processing"

Datasheets to keep handy
- TDK/InvenSense "MPU‑6000/6050 Product Specification" and "Register Map"

## 0) Code-to-Concept Map

- MPU setup (DLPF=44 Hz, FS=±500°/s & ±4 g, SMPLRT_DIV=9 → 100 Hz): see [1], [2]
- I²C Fast Mode 400 kHz, DATA_READY interrupt, FIFO accel+gyro packets: see [1], [2], [10]
- Calibration: gyro bias averaging; flat accel offset (Z-up): see [1], [2]
- Mahony attitude filter (6‑DoF, no mag): see [5]
- Cascaded control: Angle PID → Rate PID; D‑term on gyro; mixer: see [6], [7], [12], [13]
- Extra digital filters: MPU DLPF + software PT1/notch for D‑term: see [8], [12]
- In‑air autotune (small-signal Kp sweep → Ku, Pu → Tyreus–Luyben PID): see [9], [11]
- Guardrails and probe state: best practice from flight stacks: see [12], [13]

---

## 1) MPU‑6000/MPU‑6050 (Datasheet + Register Map)

1. TDK InvenSense, “MPU‑6000/6050 Product Specification”
   - Covers DLPF bandwidths/delays, FS ranges, timing, INT pin, FIFO.
   - Search: `MPU-6000 6050 product specification PDF` (TDK site)
2. TDK InvenSense, “MPU‑6000/MPU‑6050 Register Map and Descriptions”
   - All register addresses/fields, including SMPLRT_DIV, CONFIG/DLPF_CFG, INT_ENABLE, FIFO_EN, USER_CTRL, etc.
3. Jeff Rowberg, i2cdevlib MPU6050 notes (library + examples)
   - https://github.com/jrowberg/i2cdevlib/tree/master/Arduino/MPU6050

Topics to study inside: DLPF_CFG tables (bandwidth, delay), INT behavior (pulse vs latch), FIFO layout, sensitivities (LSB/°/s and LSB/g).

---

## 2) I²C, Timing, DATA_READY, FIFO

10. NXP, “I²C-bus specification and user manual (UM10204)”
    - Electrical/timing definitions (tLOW, tHIGH, setup/hold, tr/tf) for 100/400 kHz.
11. TI/Atmel/RP2040 MCU docs for I²C + external pull‑ups guidance.

Study: START/STOP, bus capacitance, pull‑ups, using INT for low‑jitter sampling, FIFO burst reads.

---

## 3) IMU Attitude Estimation (No Magnetometer)

4. Complementary filter tutorials
   - “Starlino IMU Guide” (classic article) – step-by-step implementation.
   - Wikipedia “Complementary filter” for the math idea.
5. Mahony filter (chosen in this code)
   - R. Mahony, T. Hamel, J-M. Pflimlin, “Nonlinear Complementary Filters on the Special Orthogonal Group,” IEEE TAC 2008.
     - Open versions available on HAL/uni repositories.
   - Practical code discussions and implementations are mirrored widely.
6. Madgwick filter
   - S. Madgwick, “An efficient orientation filter for IMUs” – x-io open-source resource: https://x-io.co.uk/open-source-imu-and-ahrs-algorithms/
7. Kalman filter intro (optional background)
   - Welch & Bishop, “An Introduction to the Kalman Filter” (UNC). https://www.cs.unc.edu/~welch/media/pdf/kalman_intro.pdf

What to learn: accel-derived tilt (atan2), gyro integration, drift vs gravity reference, quaternion update, normalization, PI feedback (Mahony Kp/Ki), yaw drift without magnetometer.

---

## 4) Digital Filtering (on top of DLPF)

8. Richard Lyons, “Understanding Digital Signal Processing” (book)
   - Practical IIR/FIR, PT1/EMA equivalence, notch filters, stability.
9. Steven W. Smith, “The Scientist and Engineer’s Guide to DSP” (free: https://www.dspguide.com/)

Focus: PT1/EMA low-pass for D‑term, notch near vibration bands, latency vs noise trade‑offs, sample‑rate interactions (100 Hz vs 200 Hz) and Nyquist.

---

## 5) Multirotor Flight Control Architecture

12. Beard & McLain, “Small Unmanned Aircraft: Theory and Practice” (book)
    - Dynamics, attitude/rate loops, mixers, cascaded PID patterns.
13. PX4 / ArduPilot / Betaflight docs (practical tuning insights)
    - PX4 Multicopter PID tuning: https://docs.px4.io/
    - ArduPilot Autotune docs: https://ardupilot.org/
    - Betaflight filter/PID tuning notes: https://github.com/betaflight/betaflight/wiki

Learn: inner rate PID (fast), outer angle PID (slower), yaw handling, mixer math, throttle normalization, failsafes.

---

## 6) PID Control, IMC, and Autotuning

14. Åström & Murray, “Feedback Systems: An Introduction for Scientists and Engineers” (free) – https://fbsbook.org/
15. Franklin, Powell, Emami‑Naeini, “Feedback Control of Dynamic Systems” (book)
16. Åström & Hägglund, “PID Controllers: Theory, Design, and Tuning” (book)
17. Skogestad, “Simple analytic rules for model reduction and PID controller tuning” / IMC PID rules (resources from NTNU)
18. Relay autotuning (Åström–Hägglund, 1984+, relay feedback method)

In this code we implement a conservative in‑air autotune variant:
- Small-signal Kp sweep on the rate loop (Ki=Kd=0 during sweep)
- Detect oscillation → take Ku and Pu
- Compute robust PID via Tyreus–Luyben (more conservative than classic Z‑N)
- Apply guardrails and revert on trip

IMC approach (recommended longer-term): identify a 1st‑order plant (K, τ) via PRBS/steps, pick λ≈0.3–0.6 s → compute PID. See Skogestad.

---

## 7) Calibration & Mechanics

19. IMU calibration primers (gyro bias averaging; 6‑face accel calibration)
   - Common guides from ArduPilot/PX4 communities.
20. Vibration isolation / soft-mounting guides (Betaflight/PX4 forums)

Why: gyro bias and accel offsets reduce drift/tilt error; soft-mounts + balanced props minimize high‑frequency noise that destabilizes D‑term.

---

## 8) Practical Guides & Videos

- Brian Douglas, “Control Systems Lectures” (YouTube playlist): excellent intuition on PID, stability, Bode plots.
- Steve Brunton, “Control Bootcamp” (YouTube): modern control topics, estimation.
- Andrew Tridgell (ArduPilot) talks on autotuning & controllers (YouTube).
- Betaflight/INAV/PX4 conference videos on filtering and tuning.
- x‑io videos on IMU/AHRS behavior (Madgwick/Mahony context).

Search tips: “Mahony AHRS explanation,” “complementary filter drone,” “relay autotune Åström,” “IMC PID tuning Skogestad,” “multirotor cascaded PID tutorial.”

---

## 9) Implementation references

- RP2040 Arduino core + Servo library: ESC microsecond control examples
- TinyUSB / USB HID (if you later revisit HID mode)
- Jeff Rowberg’s MPU6050 reads (for register/R/W patterns)

---

## 10) Glossary (quick)

- DLPF: sensor‑internal digital low‑pass filter (we use 44 Hz)
- SMPLRT_DIV: divides internal 1 kHz to your output rate (100 Hz)
- FIFO: on‑chip buffer for deterministic burst reads
- DATA_READY: interrupt when a new sample is produced
- Mahony filter: quaternion‑based, PI correction to gravity; great roll/pitch
- Complementary: blends gyro integration with accel tilt
- Rate PID: inner loop on angular rate (gyro)
- Angle PID: outer loop on Euler angles
- Guardrails: flight safety bounds (angles/rates/saturation)
- IMC: Internal Model Control; systematic PID tuning from identified plant
- Tyreus–Luyben: conservative PID rules from Ku/Pu (relay/sweep)

---

## 11) Suggested study path

1) Read MPU datasheet + register map sections on DLPF/INT/FIFO, then inspect `configureMPU()`.
2) Implement the complementary filter on paper; then study Mahony and compare responses.
3) Review the cascaded PID idea from Beard & McLain or PX4 docs; understand why D‑term acts on gyro.
4) Learn PT1 and notch filters (Lyons); see how they trade latency vs noise.
5) Study autotuning: relay/Ku/Pu/Tyreus–Luyben, and IMC. Try both in simulation.
6) Practice tuning on your frame: start conservative, enable guardrails, log results.

---

## 12) Quick links (starter set)

- Mahony paper (searchable reprints): “Nonlinear Complementary Filters on SO(3)”
- Madgwick open source: https://x-io.co.uk/open-source-imu-and-ahrs-algorithms/
- Welch & Bishop (Kalman intro): https://www.cs.unc.edu/~welch/media/pdf/kalman_intro.pdf
- Åström & Murray (free book): https://fbsbook.org/
- PX4 docs (multicopter tuning): https://docs.px4.io/
- ArduPilot autotune: https://ardupilot.org/
- Betaflight wiki (filters/PID): https://github.com/betaflight/betaflight/wiki
- i2cdevlib MPU6050: https://github.com/jrowberg/i2cdevlib/tree/master/Arduino/MPU6050

---

See the Reading tracker below for a checklist and quick links.

---

## Reading tracker

Use this checklist to track your progress. Check off as you study. You can also jot brief notes or dates.

- [ ] MPU‑6000/6050 Product Specification (DLPF, INT, FIFO) — see Section 1, refs [1], [2]
- [ ] MPU Register Map (SMPLRT_DIV, CONFIG, GYRO/ACCEL_CONFIG, INT, FIFO) — refs [2], [3]
- [ ] I²C bus spec and timing (400 kHz Fast Mode, pull‑ups) — ref [10]
- [ ] Wire library and RP2040 I²C particulars — MCU docs
- [ ] Gyro bias calibration procedure — Section 7
- [ ] Flat accel calibration (Z‑up) and 6‑face approach — Section 7
- [ ] Complementary filter basics and tuning — Section 3, ref [4]
- [ ] Mahony filter math and gains (Kp/Ki) — Section 3, ref [5]
- [ ] Madgwick algorithm comparison — Section 3, ref [6]
- [ ] PT1/EMA low‑pass and notch design — Section 4, refs [8], [9]
- [ ] Cascaded Angle→Rate PID structure and mixer — Section 5, refs [12], [13]
- [ ] D‑term filtering and gyro derivative pitfalls — Sections 4, 5
- [ ] Autotune via Kp sweep or relay (Ku, Pu) — Section 6, refs [16], [18]
- [ ] Tyreus–Luyben vs Z‑N/IMC trade‑offs — Section 6, refs [17], [18]
- [ ] Guardrails, probe, failsafes — Section 5, refs [12], [13]
- [ ] Practical tuning videos (Brian Douglas, Brunton) — Section 8

Optional table for notes:

| Topic | Status | Notes |
| --- | --- | --- |
| MPU datasheet + register map | [ ] |  |
| I²C timing & wiring | [ ] |  |
| Calibration (gyro/accel) | [ ] |  |
| Sensor fusion (Mahony/Madgwick/Complementary) | [ ] |  |
| Digital filters (PT1/notch) | [ ] |  |
| Cascaded PID & mixer | [ ] |  |
| Autotune (relay/IMC/T‑L rules) | [ ] |  |
| Guardrails & safety | [ ] |  |
