const M=require('../Model.js'),a=require('assert')
const two=`Display 1
   I2C bus:          /dev/i2c-5
   DRM connector:    card1-eDP-1
   Monitor:          BOE:NE135:

Display 2
   I2C bus:          /dev/i2c-12
   DRM connector:    card1-DP-2
   Monitor:          BNQ:BenQ RD270Q:R5R0001

Invalid display
   I2C bus:          /dev/i2c-9
   Monitor:          GSM:LG:
`
a.deepStrictEqual(M.parseDetect(two)[1],{bus:'12',mfg:'BNQ',model:'BenQ RD270Q'})
a.strictEqual(M.pickBus(M.parseDetect(two)),'12','RD270Q picked')
a.strictEqual(M.pickBus(M.parseDetect(two.replace('BenQ RD270Q','BenQ RD280U'))),'12','BenQ fallback')
a.strictEqual(M.pickBus(M.parseDetect('Display 1\n   I2C bus: /dev/i2c-3\n   Monitor: DEL:U2720Q:\n')),'','no BenQ')
a.strictEqual(M.pickBus(M.parseDetect('No displays found.\n')),'','empty')
a.deepStrictEqual(M.parseBrief('VCP 10 C 44 100\nVCP 81 CNC x00 x02 x00 x01\n'),{16:44,129:1})
const rd270q=`Display 1
   I2C bus:          /dev/i2c-12
   DRM connector:    card1-DP-1
   drm_connector_id: 408
   Monitor:          BNQ:BenQ RD270Q:XXXX0000000X

`
a.deepStrictEqual(M.parseDetect(rd270q),[{bus:'12',mfg:'BNQ',model:'BenQ RD270Q'}],'real ddcutil 2.2.7 detect --brief')
a.deepStrictEqual(M.parseBrief(`VCP 10 C 53 100
VCP 19 CNC x00 x05 x00 x00
VCP 81 CNC x00 x02 x00 x02
VCP D0 SNC x05
VCP D1 CNC x00 x02 x00 x00
`),{16:53,25:0,129:2,208:5,209:0},'real RD270Q getvcp --brief')
console.log('ok')
