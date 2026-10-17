# BenQ RD270Q for Omarchy

An Omarchy bar widget that controls a BenQ RD270Q monitor. Click the sun icon in the bar to open its popup. The icon turns into a moon while Night Hours Protection is on.

- **Brightness**, 0 to 100. You can also scroll on the icon.
- **Low Blue Light**, off or 1 to 5.
- **Night Hours Protection**, on or off, with a level from 1 to 10.
- **Visual Optimizer**, on or off, in **Bri + Color Temp** or **Brightness** mode.

It deliberately covers only a few everyday settings.

## Requirements

- Omarchy 4, which includes `ddcutil`.
- DDC/CI turned on in the monitor's on-screen menu.

If `ddcutil detect` lists your monitor, you are set. If the command is missing, run `omarchy pkg add ddcutil`.

## Install

```sh
omarchy plugin add https://github.com/lnhdb/omarchy-benq-rd270q --enable
```

To update it to the latest version:

```sh
omarchy plugin update lnhdb.benq-rd270q
```

To remove it:

```sh
omarchy plugin remove lnhdb.benq-rd270q
```

## Pick the monitor

The plugin finds the RD270Q by itself. Without one, it uses the first BenQ monitor it finds. To use a specific I2C bus, add `bus` to the widget's entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "lnhdb.benq-rd270q", "bus": "12" }
```

`ddcutil detect --brief` shows the bus number in the `I2C bus: /dev/i2c-N` line.

## Other monitors

The plugin is tested only on the BenQ RD270Q. Brightness works on any monitor with DDC/CI. The other controls use BenQ codes confirmed only on the RD270Q. If you try another model, open an issue and say whether it worked.

## License

MIT. See [LICENSE](LICENSE).
