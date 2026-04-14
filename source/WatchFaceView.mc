import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.ActivityMonitor;
import Toybox.Time;
import Toybox.Time.Gregorian;

class WatchFaceView extends WatchUi.WatchFace {

    // ── Tuning knobs ─────────────────────────────────────────────────────
    // Time digit scaling (awake mode)
    const TIME_SCALE_Y  = 2.00f;    // height scale  <-- tweak me
    const TIME_SCALE_X  = 1.50f;    // width  scale  <-- tweak me

    // Background color
    // const BG_COLOR = 0x000000;       // background    <-- tweak me
    const BG_COLOR = Graphics.COLOR_WHITE;       // background    <-- tweak me

    // Time digit colors (awake mode, 0xRRGGBB)
    // const TIME_COLOR_HH  = 0xFFFFFF; // hours color   <-- tweak me
    //const TIME_COLOR_MM  = 0xFFFFFF; // minutes color <-- tweak me
    const TIME_COLOR_SEP = 0x888888; // colon color   <-- tweak me
    

    const TIME_COLOR_HH  = Graphics.COLOR_BLUE; // hours color   <-- tweak me
    const TIME_COLOR_MM  = Graphics.COLOR_BLACK; // minutes color <-- tweak me

    // Date circle position (awake mode)
    const CIRC_X = 385;             // center X      <-- tweak me
    const CIRC_Y = 120;             // center Y      <-- tweak me

    // AOD (always-on display) settings
    const AOD_SCALE_X   = 0.70f;    // time width scale in AOD   <-- tweak me
    const AOD_SCALE_Y   = 1.10f;    // time height scale in AOD  <-- tweak me
    const AOD_COLOR_HH  = 0x666666; // hours color in AOD        <-- tweak me
    const AOD_COLOR_SEP = 0x444444; // colon color in AOD        <-- tweak me
    const AOD_COLOR_MM  = 0x666666; // minutes color in AOD      <-- tweak me
    const AOD_DRIFT_R   = 12;       // burn-in drift radius (px) <-- tweak me
    // ─────────────────────────────────────────────────────────────────────

    var isAsleep as Lang.Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
    }

    function onHide() as Void {
    }

    function onEnterSleep() as Void {
        isAsleep = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        isAsleep = false;
        WatchUi.requestUpdate();
    }

    // Called every minute in AOD mode — delegate to onUpdate for a clean redraw.
    function onPartialUpdate(dc as Graphics.Dc) as Void {
        onUpdate(dc);
    }

    // Format a number with comma separators (e.g. 12345 -> "12,345")
    function formatWithCommas(n as Lang.Number) as Lang.String {
        var s = n.toString();
        var result = "";
        var len = s.length();
        var mod = len % 3;
        for (var i = 0; i < len; i++) {
            if (i > 0 && (i % 3 == mod)) {
                result = result + ",";
            }
            result = result + s.substring(i, i + 1);
        }
        return result;
    }

    // Draw bold text; x is the left edge (TEXT_JUSTIFY_LEFT).
    function drawBold(bdc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                      font as Graphics.FontType, str as Lang.String) as Void {
        bdc.drawText(x - 2, y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
        bdc.drawText(x + 2, y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
        bdc.drawText(x - 1, y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
        bdc.drawText(x + 1, y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
        bdc.drawText(x,     y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Render the time into a scaled BufferedBitmap and blit it to dc.
    // cx/cy = visual center of where to place the scaled result.
    // scaleX/scaleY = scale factors.
    // colorHH/colorSep/colorMM = colors for each segment.
    // bold = whether to apply the bold offset effect.
    function drawTime(dc as Graphics.Dc,
                      cx as Lang.Number, cy as Lang.Number,
                      scaleX as Lang.Float, scaleY as Lang.Float,
                      colorHH as Lang.Number, colorSep as Lang.Number,
                      colorMM as Lang.Number,
                      bold as Lang.Boolean) as Void {
        var clockTime = System.getClockTime();
        var hhStr  = clockTime.hour.format("%02d");
        var sepStr = ":";
        var mmStr  = clockTime.min.format("%02d");
        var timeStr = hhStr + sepStr + mmStr;

        var timeFont = Graphics.FONT_NUMBER_THAI_HOT;

        var fullDims = dc.getTextDimensions(timeStr, timeFont);
        var hhDims   = dc.getTextDimensions(hhStr,   timeFont);
        var sepDims  = dc.getTextDimensions(sepStr,  timeFont);
        var tW   = fullDims[0] as Lang.Number;
        var tH   = fullDims[1] as Lang.Number;
        var hhW  = hhDims[0]   as Lang.Number;
        var sepW = sepDims[0]  as Lang.Number;

        var bbW    = tW + 10;
        var startX = (bbW - tW) / 2;   // left edge of text block in bitmap
        var hhX    = startX;
        var sepX   = startX + hhW;
        var mmX    = startX + hhW + sepW;

        var bbRef = Graphics.createBufferedBitmap({:width => bbW, :height => tH});
        var bbRaw = bbRef.get();
        if (!(bbRaw instanceof Graphics.BufferedBitmap)) {
            // Fallback: draw unscaled, white
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - tH / 2, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var bb  = bbRaw as Graphics.BufferedBitmap;
        var bdc = bb.getDc();
        bdc.setColor(BG_COLOR, BG_COLOR);
        bdc.clear();

        bdc.setColor(colorHH, Graphics.COLOR_TRANSPARENT);
        if (bold) {
            drawBold(bdc, hhX, 0, timeFont, hhStr);
        } else {
            bdc.drawText(hhX, 0, timeFont, hhStr, Graphics.TEXT_JUSTIFY_LEFT);
        }

        bdc.setColor(colorSep, Graphics.COLOR_TRANSPARENT);
        bdc.drawText(sepX, 0, timeFont, sepStr, Graphics.TEXT_JUSTIFY_LEFT);

        bdc.setColor(colorMM, Graphics.COLOR_TRANSPARENT);
        if (bold) {
            drawBold(bdc, mmX, 0, timeFont, mmStr);
        } else {
            bdc.drawText(mmX, 0, timeFont, mmStr, Graphics.TEXT_JUSTIFY_LEFT);
        }

        var xform   = new Graphics.AffineTransform();
        xform.scale(scaleX, scaleY);
        var scaledW = (bbW * scaleX).toNumber();
        var scaledH = (tH  * scaleY).toNumber();
        dc.drawBitmap2(cx - scaledW / 2, cy - scaledH / 2, bb, {:transform => xform});
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var W  = dc.getWidth();
        var H  = dc.getHeight();
        var cx = W / 2;
        var cy = H / 2;

        dc.setColor(BG_COLOR, BG_COLOR);
        dc.clear();

        if (isAsleep) {
            // ── AOD mode: time only, dimmer, drifted to prevent burn-in ──
            // Drift the center position in a slow circle keyed to the minute.
            // One full revolution per hour; radius = AOD_DRIFT_R pixels.
            var minute = System.getClockTime().min.toFloat();
            var angle  = minute * Math.PI / 30.0f;   // 0..2π over 60 min
            var driftX = (AOD_DRIFT_R.toFloat() * Math.sin(angle)).toNumber();
            var driftY = (AOD_DRIFT_R.toFloat() * Math.cos(angle)).toNumber();

            drawTime(dc,
                     cx + driftX, cy + driftY,
                     AOD_SCALE_X, AOD_SCALE_Y,
                     AOD_COLOR_HH, AOD_COLOR_SEP, AOD_COLOR_MM,
                     false);
        } else {
            // ── Awake mode: full watch face ──────────────────────────────

            // TIME (drawn first so other elements render on top)
            drawTime(dc,
                     cx, 155 + (dc.getTextDimensions("00:00", Graphics.FONT_NUMBER_THAI_HOT)[1] as Lang.Number) / 2,
                     TIME_SCALE_X, TIME_SCALE_Y,
                     TIME_COLOR_HH, TIME_COLOR_SEP, TIME_COLOR_MM,
                     true);

            // STEPS (drawn after time so it sits on top)
            var steps = 0;
            var actInfo = ActivityMonitor.getInfo();
            if (actInfo != null) {
                var s = actInfo.steps;
                if (s != null) { steps = s; }
            }
            dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 28, Graphics.FONT_SMALL,
                        formatWithCommas(steps) + " steps",
                        Graphics.TEXT_JUSTIFY_CENTER);

            // DAY / DATE circle
            var now    = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var dayNum = now.day_of_week as Lang.Number;
            var dayNames = ["", "SU", "MO", "TU", "WE", "TH", "FR", "SA"];
            var dayStr  = dayNum >= 1 && dayNum <= 7 ? dayNames[dayNum] : "--";
            var dateStr = now.day.toString();
            var circR   = 42;

            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(CIRC_X, CIRC_Y, circR);
            dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawCircle(CIRC_X, CIRC_Y, circR);
            dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CIRC_X, CIRC_Y - 30, Graphics.FONT_XTINY, dayStr, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CIRC_X, CIRC_Y - 8,  Graphics.FONT_SMALL,  dateStr, Graphics.TEXT_JUSTIFY_CENTER);

            // BATTERY
            var sysStats = System.getSystemStats();
            var batt     = sysStats.battery.toNumber();
            var battColor;
            if (batt <= 20) {
                battColor = Graphics.COLOR_RED;
            } else if (batt <= 50) {
                battColor = Graphics.COLOR_YELLOW;
            } else {
                battColor = 0x00CC44;
            }

            var bx   = cx - 30;
            var by   = 392;
            var bw   = 44;
            var bh   = 18;
            var nubW = 4;
            var nubH = 8;
            var fillW = bw * batt / 100;
            if (fillW < 1) { fillW = 1; }

            dc.setColor(battColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx + 1, by + 1, fillW - 1, bh - 2);
            dc.setPenWidth(1);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(bx, by, bw, bh);
            dc.fillRectangle(bx + bw, by + (bh - nubH) / 2, nubW, nubH);
            dc.setColor(battColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bx + bw + nubW + 6, by - 1, Graphics.FONT_TINY,
                        batt.toString() + "%", Graphics.TEXT_JUSTIFY_LEFT);
        }
    }
}
