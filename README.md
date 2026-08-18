# AirPrint for Legacy Brother Printers on Debian

Turn an older network-connected Brother printer into an AirPrint printer using Debian, CUPS and Avahi.

This guide is intentionally broader than one printer model. It documents a setup tested end-to-end on a **Brother MFC-9460CDN**, while keeping the procedure applicable to many older Brother network printers that use the classic Brother CUPS/LPR driver stack.

## Tested setup

- Debian 12 (Bookworm)
- CUPS 2.4.2
- Avahi / DNS-SD
- Brother MFC-9460CDN over Ethernet
- Brother Linux printer driver
- iPhone / iOS AirPrint
- A4, colour and duplex printing

The exact driver options and queue names can differ between Brother models. Always inspect your own printer with `lpinfo` and `lpoptions` rather than copying model-specific options blindly.

## Why this guide exists

The basic CUPS + Avahi part is well known. The less obvious problems are with older Brother printers and AirPrint clients:

- some models are not supported by `brlaser`;
- a generic PostScript queue may not work correctly even when the printer advertises PostScript compatibility;
- iOS can show only US paper sizes even when the CUPS queue default is already A4;
- `media-default` can be A4 while `media-ready` still advertises Letter/Legal/Envelope #10;
- on CUPS 2.4, `ReadyPaperSizes` can be the missing piece for the iOS paper-size menu.

The MFC-9460CDN-specific details are in [`docs/MFC-9460CDN.md`](docs/MFC-9460CDN.md).

---

## 1. Install CUPS and Avahi

```bash
sudo apt update
sudo apt install -y \
  cups \
  cups-client \
  cups-ipp-utils \
  avahi-daemon \
  avahi-utils

sudo systemctl enable --now cups
sudo systemctl enable --now avahi-daemon
```

Check both services:

```bash
systemctl is-active cups
systemctl is-active avahi-daemon
```

Both should return:

```text
active
```

## 2. Discover the Brother printer

```bash
lpinfo -v
```

Typical network results include one or more of:

```text
network dnssd://Brother%20..._pdl-datastream._tcp.local/
network lpd://printer-hostname/BINARY_P1
network socket
network ipp
```

Also useful:

```bash
avahi-browse -rt _ipp._tcp
avahi-browse -rt _printer._tcp
```

For a permanent setup, reserve a fixed IP address for the printer in DHCP.

## 3. Check whether a native Debian driver exists

```bash
lpinfo -m | grep -i brother
```

or, for a specific model:

```bash
lpinfo -m | grep -i 'MODEL-NAME'
```

If your printer is supported by a native Debian/OpenPrinting driver, use that.

If it is not, many older Brother models still have a classic Linux driver available from Brother Support.

Brother's documented installer workflow is:

```bash
gunzip linux-brprinter-installer-*.gz
sudo bash linux-brprinter-installer-* MODEL-NAME
```

See Brother's official Linux installation instructions for your exact model before downloading or installing anything.

## 4. Choose the printer Device URI carefully

Use what your printer actually advertises:

```bash
lpinfo -v
```

For the tested MFC-9460CDN setup, the Brother driver worked correctly with LPD:

```text
lpd://PRINTER_IP/BINARY_P1
```

You can update an existing queue to a fixed IP later:

```bash
sudo lpadmin -p PRINTER_QUEUE -v lpd://PRINTER_IP/BINARY_P1
```

Do not assume `BINARY_P1` exists on every Brother model. Use the URI discovered on your network or documented for your printer.

## 5. Test local printing before enabling AirPrint

Check the queue:

```bash
lpstat -t
```

Then print the CUPS test page:

```bash
lp -d PRINTER_QUEUE /usr/share/cups/data/testprint
```

Do not continue until normal printing works from Debian.

## 6. Share the queue through CUPS

```bash
sudo lpadmin -p PRINTER_QUEUE -o printer-is-shared=true
sudo cupsctl --share-printers
sudo systemctl restart cups
sudo systemctl restart avahi-daemon
```

Avoid `cupsctl --remote-any` unless you explicitly need it. AirPrint clients need access to the shared printer, not unrestricted remote CUPS administration.

At this point, the printer should normally appear in the iPhone/iPad print dialog.

## 7. Inspect printer options

```bash
lpoptions -p PRINTER_QUEUE -l
```

This tells you the real PPD option names for your printer.

For example, the MFC-9460CDN exposes Brother-specific options such as:

```text
PageSize
BRDuplex
BRResolution
BRMonoColor
BRMediaType
BRSkipBlank
```

Do not assume these names are identical on other models.

## 8. Set A4 and other defaults

Set only options your printer actually reports with `lpoptions -l`.

Generic example:

```bash
sudo lpadmin -p PRINTER_QUEUE -o PageSize=A4
```

Then verify:

```bash
lpoptions -p PRINTER_QUEUE -l
```

An asterisk marks the current default, for example:

```text
PageSize/Media Size: *A4 Letter Legal ...
```

## 9. Diagnose the iOS "A4 missing" problem

A common trap is that CUPS can have the correct A4 default while iOS still displays only US formats.

Inspect the IPP attributes exposed by CUPS:

```bash
ipptool -tv ipp://localhost:631/printers/PRINTER_QUEUE \
  /usr/share/cups/ipptool/get-printer-attributes.test \
  | grep -E 'media-default|media-ready|media-col-ready|media-supported'
```

A problematic result can look like this:

```text
media-default = iso_a4_210x297mm
media-ready = na_letter_8.5x11in,na_legal_8.5x14in,na_number-10_4.125x9.5in
```

In the tested setup, iOS offered exactly the formats listed in `media-ready`, even though `media-default` was already A4.

### Fix with `ReadyPaperSizes`

Back up the CUPS configuration first:

```bash
sudo cp /etc/cups/cupsd.conf /etc/cups/cupsd.conf.bak-airprint
```

Add or set these directives in `/etc/cups/cupsd.conf`:

```text
DefaultPaperSize A4
ReadyPaperSizes A4,A5,A6,EnvDL
```

CUPS documents `ReadyPaperSizes` as the list of potential paper sizes reported as ready/loaded, filtered by what each queue supports.

Validate the configuration before restarting:

```bash
sudo cupsd -t
```

No output means the syntax is valid.

Then clear the cached printer attributes and restart CUPS:

```bash
sudo systemctl stop cups
sudo rm -rf /var/cache/cups/*
sudo systemctl start cups
sudo systemctl restart avahi-daemon
```

Check again:

```bash
ipptool -tv ipp://localhost:631/printers/PRINTER_QUEUE \
  /usr/share/cups/ipptool/get-printer-attributes.test \
  | grep -E 'media-default|media-ready|media-col-ready'
```

You should now see ISO paper sizes in `media-ready`, for example:

```text
media-default = iso_a4_210x297mm
media-ready = iso_a4_210x297mm,iso_a5_148x210mm,iso_a6_105x148mm,iso_dl_110x220mm
```

Close and reopen the iOS print dialog, then select the printer again.

If you only ever use A4, you can use a stricter configuration:

```text
ReadyPaperSizes A4
```

## 10. Useful diagnostics

### Queue and backend

```bash
lpstat -t
lpstat -v
```

### Available driver options

```bash
lpoptions -p PRINTER_QUEUE -l
```

### DNS-SD / AirPrint discovery

```bash
avahi-browse -rt _ipp._tcp
```

### IPP capabilities advertised to iOS

```bash
ipptool -tv ipp://localhost:631/printers/PRINTER_QUEUE \
  /usr/share/cups/ipptool/get-printer-attributes.test
```

### Test CUPS configuration

```bash
cupsd -t
```

### Recent CUPS logs

```bash
journalctl -u cups --no-pager -n 100
sudo tail -n 100 /var/log/cups/error_log
```

## Troubleshooting

### Printer appears in `lpinfo -v`, but no queue exists

Install the correct driver and create the queue first. AirPrint sharing only works once normal printing from CUPS works.

### Generic PostScript produces blank pages

Do not assume that a generic PostScript PPD is interchangeable with the Brother driver. On the tested MFC-9460CDN, the generic PostScript queue accepted jobs but produced blank sheets. Installing the official Brother Linux driver and using its LPD queue fixed printing.

### iPhone sees the printer but A4 is missing

Compare:

```text
media-default
media-ready
media-col-ready
```

If `media-default` is A4 but `media-ready` is still Letter/Legal/Env10, configure `DefaultPaperSize` and `ReadyPaperSizes`, validate `cupsd.conf`, clear `/var/cache/cups`, and restart CUPS/Avahi.

### iPhone cannot see the printer at all

Confirm:

- the queue is shared;
- Avahi is running;
- the iPhone and CUPS server can exchange mDNS/DNS-SD traffic;
- VLAN/firewall rules are not blocking multicast DNS;
- `avahi-browse -rt _ipp._tcp` shows the shared queue.

## Compatibility

This repository is **tested on the Brother MFC-9460CDN**.

The same approach is likely useful for many older Brother network laser/MFC devices that:

- are not natively AirPrint-capable;
- have an Ethernet/Wi-Fi print interface;
- have a Brother Linux CUPS/LPR driver;
- expose LPD, socket/JetDirect or another CUPS-supported backend.

Model-specific confirmation is welcome through GitHub Issues or pull requests.

## References

- [Brother Support: MFC-9460CDN Linux printer-driver installation](https://support.brother.com/g/b/faqend.aspx?c=ch&faqid=faq00100556_000&lang=fr&prod=mfc9460cdn_all)
- [OpenPrinting CUPS source and documentation](https://github.com/OpenPrinting/cups)
- [CUPS `cupsd.conf` documentation (`DefaultPaperSize`, `ReadyPaperSizes`)](https://github.com/OpenPrinting/cups/blob/master/man/cupsd.conf.5)
- [OpenPrinting discussion: sharing an older printer via AirPrint with CUPS 2.4](https://github.com/OpenPrinting/cups/discussions/369)

## Contributing

If this works on another Brother model, please open an issue or pull request with:

- printer model;
- Debian/Ubuntu version;
- CUPS version;
- Device URI/backend used;
- driver used;
- whether colour/duplex works;
- whether the A4 `ReadyPaperSizes` fix was required.

That will help turn this into a useful compatibility reference for legacy Brother printers.

## License

This project is licensed under the [MIT License](LICENSE).
