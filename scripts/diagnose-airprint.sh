#!/usr/bin/env bash
set -u

QUEUE="${1:-}"

if [ -z "$QUEUE" ]; then
  echo "Usage: $0 PRINTER_QUEUE"
  echo
  echo "Available queues:"
  lpstat -p 2>/dev/null || true
  exit 1
fi

IPP_URI="ipp://localhost:631/printers/${QUEUE}"
IPP_TEST="/usr/share/cups/ipptool/get-printer-attributes.test"

echo "== CUPS service =="
systemctl is-active cups 2>/dev/null || true

echo
echo "== Avahi service =="
systemctl is-active avahi-daemon 2>/dev/null || true

echo
echo "== Queue =="
lpstat -p "$QUEUE" 2>&1 || true
lpstat -v "$QUEUE" 2>&1 || true

echo
echo "== Queue defaults =="
lpoptions -p "$QUEUE" 2>&1 || true

echo
echo "== Relevant PPD options =="
lpoptions -p "$QUEUE" -l 2>/dev/null | grep -E 'PageSize|Duplex|Resolution|Color|Mono|InputSlot|MediaType|SkipBlank' || true

echo
echo "== AirPrint / IPP media attributes =="
if command -v ipptool >/dev/null 2>&1 && [ -f "$IPP_TEST" ]; then
  ipptool -tv "$IPP_URI" "$IPP_TEST" 2>/dev/null \
    | grep -E 'media-default|media-ready|media-col-ready|media-supported|urf-supported' || true
else
  echo "ipptool or $IPP_TEST is missing. Install cups-ipp-utils."
fi

echo
echo "== DNS-SD / Avahi =="
if command -v avahi-browse >/dev/null 2>&1; then
  timeout 5 avahi-browse -rt _ipp._tcp 2>/dev/null | grep -E "${QUEUE}|printer|hostname|address|port|txt" || true
else
  echo "avahi-browse is missing. Install avahi-utils."
fi

echo
echo "== CUPS paper directives =="
grep -E '^[[:space:]]*(DefaultPaperSize|ReadyPaperSizes)[[:space:]]' /etc/cups/cupsd.conf 2>/dev/null || echo "No explicit DefaultPaperSize/ReadyPaperSizes directives found."

echo
echo "== CUPS configuration syntax =="
if cupsd -t; then
  echo "cupsd.conf: OK"
else
  echo "cupsd.conf: ERROR"
fi

echo
echo "== Recent CUPS journal =="
journalctl -u cups --no-pager -n 20 2>/dev/null || true
