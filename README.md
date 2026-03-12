
# Detox — Digital Wellbeing & Focus Control

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Android-green)
![Firebase](https://img.shields.io/badge/Firebase-Integrated-orange)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

Detox is a Flutter-based mobile application designed to help users reduce digital distractions, build healthier device habits, and maintain focus using intelligent app blocking, usage analytics, and location-based automation.

The app combines screen time monitoring, focus sessions, and smart restrictions to create a complete digital wellbeing system.

---

# Features

## Screen Time Monitoring
- Daily usage summary
- Weekly analytics
- Most used apps
- Estimated pickups

Uses Android **Usage Access permission**.

## Focus Sessions
- Timer presets (15 / 25 / 45 / 60 minutes)
- App blocking during sessions
- Background notification timer
- Automatic unblocking

## App Blocking System
Uses Android overlay permissions to block selected apps during focus sessions.

## Daily Screen Time Limits
Users can define maximum daily usage time.

## Per-App Limits
Individual limits for selected apps.

## Concentration Zones
Location-based zones where selected apps are automatically blocked.

## Sponsor System
Accountability feature allowing a sponsor to approve temporary unlock requests.

---

# Architecture

Project structure:

lib/
- models/
- services/
- screens/
- widgets/
- theme/

---

# Local Storage

Uses **SharedPreferences** to store:

- onboarding state
- daily limits
- app limits
- concentration zones
- habits
- theme preferences

Permission onboarding is stored **locally per device**.

---

# Cloud Sync

Firebase is used to synchronize:

- habits
- daily limits
- app limits
- zones
- sponsor relationships

Device permission state is **not synchronized**.

---

# Android Permissions

Required:

- PACKAGE_USAGE_STATS
- SYSTEM_ALERT_WINDOW
- ACCESS_FINE_LOCATION
- ACCESS_COARSE_LOCATION

---

# Installation

Clone repository:

git clone github.com/IcedDino/detox.git
cd detox

Install dependencies:

flutter pub get

---

# Build APK

Generate optimized APK:

flutter build apk --release --split-per-abi

Output:

build/app/outputs/flutter-apk/

Use:

app-arm64-v8a-release.apk

---

# Development

Run locally:

flutter run

---

# License

MIT License
