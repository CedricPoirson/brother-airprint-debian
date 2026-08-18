# Compatibility matrix

This project aims to document AirPrint support for legacy Brother printers shared through Debian/CUPS.

Only configurations that have actually been reported as working should be marked **Tested**.

| Brother model | OS | CUPS | Driver | Backend | AirPrint | A4 | Duplex | Status |
|---|---|---|---|---|---|---|---|---|
| MFC-9460CDN | Debian 12 | 2.4.2 | Brother official Linux driver | LPD (`BINARY_P1`) | Yes | Yes | Yes | **Tested** |

## Add your printer

If another Brother model works, please open an issue with:

- exact model name;
- Linux distribution and version;
- CUPS version (`dpkg-query -W cups` or equivalent);
- driver used;
- Device URI/backend (`lpstat -v`);
- colour support;
- duplex support;
- whether AirPrint discovery worked automatically;
- whether the `ReadyPaperSizes` fix was needed for A4.

A model should only be added as **Tested** once somebody has confirmed real printing from an iPhone/iPad.
