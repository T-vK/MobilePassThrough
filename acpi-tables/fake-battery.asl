DefinitionBlock ("", "SSDT", 1, "BOCHS", "BXPCSSDT", 0x00000001)
{
    External (_SB_.PCI0, DeviceObj)

    Scope (_SB.PCI0)
    {
        Device (BAT0)
        {
            Name (_HID, EisaId ("PNP0C0A") /* Control Method Battery */)  // _HID: Hardware ID
            Name (_UID, Zero)  // _UID: Unique ID
            Method (_STA, 0, NotSerialized)  // _STA: Status
            {
                Return (0x1F)
            }

            Method (_BIF, 0, NotSerialized)  // _BIF: Battery Information
            {
                Return (Package (0x0D)
                {
                    One, 
                    0x1770, 
                    0x1770, 
                    One, 
                    0x39D0, 
                    0x0258, 
                    0x012C, 
                    0x3C, 
                    0x3C, 
                    "", 
                    "", 
                    "LION", 
                    ""
                })
            }

            Method (_BST, 0, NotSerialized)  // _BST: Battery Status
            {
                Return (Package (0x04)
                {
                    Zero, 
                    Zero, 
                    0x1770, 
                    0x39D0
                })
            }
        }
    }
}