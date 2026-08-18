---
name: Brother model compatibility report
about: Report a working or problematic legacy Brother AirPrint setup
title: "[Model] "
labels: ""
assignees: ""
---

## Printer

- Brother model:
- Connection: Ethernet / Wi-Fi / USB
- Firmware version (if known):

## Linux server

- Distribution/version:
- CUPS version:
- Avahi version (optional):

## Driver and backend

- Driver used:
- Queue name:
- Output of `lpstat -v`:

```text
paste here
```

## AirPrint result

- Printer visible on iPhone/iPad: Yes / No
- Printing works: Yes / No
- Colour works: Yes / No / N/A
- Duplex works: Yes / No / N/A
- A4 shown correctly in iOS: Yes / No / N/A
- `ReadyPaperSizes` fix required: Yes / No

## Relevant IPP media attributes

```bash
ipptool -tv ipp://localhost:631/printers/PRINTER_QUEUE \
  /usr/share/cups/ipptool/get-printer-attributes.test \
  | grep -E 'media-default|media-ready|media-col-ready|media-supported'
```

```text
paste output here
```

## Notes

Describe any extra steps, errors or model-specific options that were needed.
