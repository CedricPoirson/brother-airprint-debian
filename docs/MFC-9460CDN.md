# Brother MFC-9460CDN — tested configuration

This page records the configuration that was tested successfully with a Brother MFC-9460CDN on Debian 12.

## Environment

- Printer: Brother MFC-9460CDN
- Connection: Ethernet
- Server: Debian 12 (Bookworm)
- CUPS: 2.4.2-3+deb12u9
- Discovery: Avahi / DNS-SD
- Client tested: iPhone / iOS AirPrint

## Discovery

Before installing the Brother driver, CUPS discovered the printer as:

```text
network dnssd://Brother%20MFC-9460CDN._pdl-datastream._tcp.local/
network lpd://Imprimante-Brother/BINARY_P1
```

The LPD backend was used for the final working configuration.

For a stable installation, reserve a fixed printer IP address in DHCP and use it in the Device URI:

```text
lpd://PRINTER_IP/BINARY_P1
```

## Driver

The Debian `brlaser` package did not contain a dedicated MFC-9460CDN entry in the tested environment.

A generic PostScript PPD accepted jobs but produced blank sheets.

The final setup therefore used Brother's official Linux installer for the MFC-9460CDN.

Example installation flow:

```bash
gunzip linux-brprinter-installer-*.gz
sudo bash linux-brprinter-installer-* MFC-9460CDN
```

When asked for the Device URI, select the discovered LPD URI or specify the printer's fixed IP address.

## Queue state

The resulting queue looked like:

```text
scheduler is running
device for MFC9460CDN: lpd://Imprimante-Brother/BINARY_P1
MFC9460CDN accepting requests
printer MFC9460CDN is idle. enabled
```

## Verify normal printing first

```bash
lp -d MFC9460CDN /usr/share/cups/data/testprint
```

Do not configure AirPrint until this produces a normal printed test page.

## Share the queue

```bash
sudo lpadmin -p MFC9460CDN -o printer-is-shared=true
sudo cupsctl --share-printers
sudo systemctl restart cups
sudo systemctl restart avahi-daemon
```

The printer should then appear in the iOS print dialog.

## Tested defaults

Inspect the model-specific options first:

```bash
lpoptions -p MFC9460CDN -l
```

The tested queue exposed:

```text
PageSize/Media Size
BRDuplex/Two-Sided Printing
BRInputSlot/Paper Source
BRResolution/Print Quality
BRMonoColor/Color / Mono
BRMediaType/Media Type
BRColorMatching/Color Mode
BRGray/Improve Gray Color
BRTonerSaveMode/Toner Save Mode
BRSkipBlank/Skip Blank Page
```

The following defaults were used successfully:

```bash
sudo lpadmin -p MFC9460CDN \
  -o PageSize=A4 \
  -o BRDuplex=DuplexNoTumble \
  -o BRInputSlot=AutoSelect \
  -o BRResolution=600dpi \
  -o BRMonoColor=Auto \
  -o BRMediaType=Plain \
  -o BRColorMatching=Normal \
  -o BRGray=ON \
  -o BRTonerSaveMode=OFF \
  -o BRSkipBlank=ON
```

`DuplexNoTumble` gives the normal long-edge duplex orientation for portrait A4 documents.

Verify:

```bash
lpoptions -p MFC9460CDN -l | grep -E 'PageSize|BRDuplex|BRResolution|BRMonoColor|BRSkipBlank'
```

Expected important defaults:

```text
PageSize/Media Size: *A4 ...
BRDuplex/Two-Sided Printing: DuplexTumble *DuplexNoTumble None
BRResolution/Print Quality: *600dpi ...
BRMonoColor/Color / Mono: *Auto ...
BRSkipBlank/Skip Blank Page: OFF *ON
```

## The iOS A4 problem

Even after the queue and PPD were correctly set to A4, iOS only offered:

- Envelope #10
- Letter
- Legal

CUPS itself reported:

```text
media-default = iso_a4_210x297mm
```

but also:

```text
media-ready = na_letter_8.5x11in,na_legal_8.5x14in,na_number-10_4.125x9.5in
```

This matched exactly what iOS displayed.

### Confirm the PPD defaults

```bash
grep -E '^\*Default(PageSize|PageRegion|ImageableArea|PaperDimension)' \
  /etc/cups/ppd/MFC9460CDN.ppd
```

The tested working PPD reported:

```text
*DefaultPageSize: A4
*DefaultPageRegion: A4
*DefaultImageableArea: A4
*DefaultPaperDimension: A4
```

So changing the PPD again was not the solution.

### Inspect IPP media attributes

```bash
ipptool -tv ipp://localhost:631/printers/MFC9460CDN \
  /usr/share/cups/ipptool/get-printer-attributes.test \
  | grep -E 'media-default|media-ready|media-col-ready|media-supported'
```

### Working fix

Back up the CUPS configuration:

```bash
sudo cp /etc/cups/cupsd.conf /etc/cups/cupsd.conf.bak-airprint
```

Set:

```text
DefaultPaperSize A4
ReadyPaperSizes A4,A5,A6,EnvDL
```

in `/etc/cups/cupsd.conf`.

Validate:

```bash
sudo cupsd -t
```

Then clear the CUPS cache and restart services:

```bash
sudo systemctl stop cups
sudo rm -rf /var/cache/cups/*
sudo systemctl start cups
sudo systemctl restart avahi-daemon
```

After reopening the iOS print dialog and selecting the printer again, A4 was correctly offered.

If the printer is only ever loaded with A4, the stricter setting below is also reasonable:

```text
ReadyPaperSizes A4
```

## Final architecture

```text
iPhone / iPad
     |
  AirPrint
  IPP + DNS-SD
     |
Debian 12
CUPS + Avahi
     |
Brother Linux driver
     |
LPD / BINARY_P1
     |
Brother MFC-9460CDN
```

## Notes

- Setting a system-wide default printer is not required for AirPrint.
- `cupsctl --share-printers` is sufficient for sharing; do not enable unrestricted remote administration unless you need it.
- A fixed DHCP reservation for the printer avoids name-resolution surprises.
- If a generic PostScript queue prints blank pages, switch to the correct Brother driver before troubleshooting AirPrint.
