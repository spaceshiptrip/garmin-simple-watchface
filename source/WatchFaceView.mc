import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.ActivityMonitor;
import Toybox.Time;
import Toybox.Time.Gregorian;

class WatchFaceView extends WatchUi.WatchFace {

    // ── Tuning knobs ─────────────────────────────────────────────────────
    // Time digit scaling
    const TIME_SCALE_Y  = 2.00f;    // height scale  <-- tweak me
    const TIME_SCALE_X  = 1.20f;    // width  scale  <-- tweak me

    // Time digit colors (0xRRGGBB)
    const TIME_COLOR_HH  = 0xFFFFFF; // hours color   <-- tweak me
    const TIME_COLOR_SEP = 0x888888; // colon color   <-- tweak me
    const TIME_COLOR_MM  = 0xFFFFFF; // minutes color <-- tweak me

    // Date circle position
    const CIRC_X = 385;             // center X      <-- tweak me
    const CIRC_Y = 120;             // center Y      <-- tweak me
    // ─────────────────────────────────────────────────────────────────────

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
    }

    function onHide() as Void {
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

    // Draw bold text (x is left edge, LEFT_JUSTIFY)
    function drawBold(bdc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                      font as Graphics.FontType, str as Lang.String) as Void {
        bdc.drawText(x - 2, y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
        bdc.drawText(x + 2, y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
        bdc.drawText(x - 1, y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
        bdc.drawText(x + 1, y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
        bdc.drawText(x,     y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var W = dc.getWidth();    // 454
        var H = dc.getHeight();   // 454
        var cx = W / 2;           // 227

        // ── Background ──────────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // ── TIME (center, maximum size) ──────────────────────────────────
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var min  = clockTime.min;
        var hhStr  = hour.format("%02d");
        var sepStr = ":";
        var mmStr  = min.format("%02d");
        var timeStr = hhStr + sepStr + mmStr;

        var timeFont = Graphics.FONT_NUMBER_THAI_HOT;
        var timeY = 155;

        // Measure the parts so we can color HH and MM independently
        var fullDims = dc.getTextDimensions(timeStr, timeFont);
        var hhDims   = dc.getTextDimensions(hhStr,   timeFont);
        var sepDims  = dc.getTextDimensions(sepStr,  timeFont);
        var tW = fullDims[0] as Lang.Number;
        var tH = fullDims[1] as Lang.Number;
        var hhW  = hhDims[0]  as Lang.Number;
        var sepW = sepDims[0] as Lang.Number;

        var bbW = tW + 10;
        // Left edge of the text block inside the bitmap (centered in bitmap)
        var startX = (bbW - tW) / 2;
        var hhX  = startX;
        var sepX = startX + hhW;
        var mmX  = startX + hhW + sepW;

        var bbRef = Graphics.createBufferedBitmap({:width => bbW, :height => tH});
        var bbRaw = bbRef.get();
        if (bbRaw instanceof Graphics.BufferedBitmap) {
            var bb = bbRaw as Graphics.BufferedBitmap;
            var bdc = bb.getDc();
            bdc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            bdc.clear();

            // Hours
            bdc.setColor(TIME_COLOR_HH, Graphics.COLOR_TRANSPARENT);
            drawBold(bdc, hhX, 0, timeFont, hhStr);

            // Separator
            bdc.setColor(TIME_COLOR_SEP, Graphics.COLOR_TRANSPARENT);
            bdc.drawText(sepX, 0, timeFont, sepStr, Graphics.TEXT_JUSTIFY_LEFT);

            // Minutes
            bdc.setColor(TIME_COLOR_MM, Graphics.COLOR_TRANSPARENT);
            drawBold(bdc, mmX, 0, timeFont, mmStr);

            // Scale and blit
            var xform = new Graphics.AffineTransform();
            xform.scale(TIME_SCALE_X, TIME_SCALE_Y);
            var scaledW = (bbW * TIME_SCALE_X).toNumber();
            var scaledH = (tH  * TIME_SCALE_Y).toNumber();
            var drawX = cx - scaledW / 2;
            var drawY = timeY + tH / 2 - scaledH / 2;
            dc.drawBitmap2(drawX, drawY, bb, {:transform => xform});
        } else {
            // Fallback: no scaling, white only
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - 2, timeY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx + 2, timeY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx,     timeY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── STEPS (top — drawn after time so it stays on top) ────────────
        var steps = 0;
        var actInfo = ActivityMonitor.getInfo();
        if (actInfo != null) {
            var s = actInfo.steps;
            if (s != null) {
                steps = s;
            }
        }
        var stepsStr = formatWithCommas(steps) + " steps";
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 28, Graphics.FONT_SMALL, stepsStr, Graphics.TEXT_JUSTIFY_CENTER);

        // ── DAY / DATE circle ────────────────────────────────────────────
        // 2-letter abbreviations: SU MO TU WE TH FR SA
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayNum = now.day_of_week as Lang.Number;
        var dayNames = ["", "SU", "MO", "TU", "WE", "TH", "FR", "SA"];
        var dayStr = dayNum >= 1 && dayNum <= 7 ? dayNames[dayNum] : "--";
        var dateStr = now.day.toString();

        var circR = 42;

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(CIRC_X, CIRC_Y, circR);

        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(CIRC_X, CIRC_Y, circR);

        // Day label: small, near the top of the circle
        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CIRC_X, CIRC_Y - 30, Graphics.FONT_XTINY, dayStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Date number: centered in the lower half of the circle
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CIRC_X, CIRC_Y - 8, Graphics.FONT_SMALL, dateStr, Graphics.TEXT_JUSTIFY_CENTER);

        // ── BATTERY (bottom) ─────────────────────────────────────────────
        var sysStats = System.getSystemStats();
        var batt = sysStats.battery.toNumber();

        var battColor;
        if (batt <= 20) {
            battColor = Graphics.COLOR_RED;
        } else if (batt <= 50) {
            battColor = Graphics.COLOR_YELLOW;
        } else {
            battColor = 0x00CC44;
        }

        var bx = cx - 30;
        var by = 392;
        var bw = 44;
        var bh = 18;
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
        dc.drawText(bx + bw + nubW + 6, by - 1, Graphics.FONT_TINY, batt.toString() + "%", Graphics.TEXT_JUSTIFY_LEFT);
    }
}
