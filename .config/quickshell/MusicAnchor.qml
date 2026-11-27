pragma Singleton
import QtQuick

// Where the bar's marquee sits on screen. The bar writes it, the music panel
// reads it, so the card drops out from under the title instead of opening in
// the middle of the display.
QtObject {
    property real center: 0     // screen x of the marquee's middle
    property real bottom: 0     // screen y of its lower edge
    property bool valid: false  // false: no marquee on screen, fall back to centred
}
