import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.ActivityMonitor;
import Toybox.Time;
import Toybox.Time.Gregorian;

class WatchFaceView extends WatchUi.WatchFace {

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

    function onUpdate(dc as Graphics.Dc) as Void {
        var W = dc.getWidth();    // 454
        var H = dc.getHeight();   // 454
        var cx = W / 2;           // 227

        // ── Background ──────────────────────────────────────────────────
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // ── STEPS (top) ──────────────────────────────────────────────────
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

        // ── TIME (center, maximum size) ──────────────────────────────────
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var min  = clockTime.min;
        var timeStr = hour.format("%02d") + ":" + min.format("%02d");

        // ── TIME: bold + 15% taller via BufferedBitmap + AffineTransform ──
        var timeFont = Graphics.FONT_NUMBER_THAI_HOT;
        var timeY = 155;
        var dims = dc.getTextDimensions(timeStr, timeFont);
        var tW = dims[0] as Lang.Number;
        var tH = dims[1] as Lang.Number;
        var bbW = tW + 10;

        var bbRef = Graphics.createBufferedBitmap({:width => bbW, :height => tH});
        var bbRaw = bbRef.get();
        if (bbRaw instanceof Graphics.BufferedBitmap) {
            var bb = bbRaw as Graphics.BufferedBitmap;
            // Draw bold text onto off-screen bitmap
            var bdc = bb.getDc();
            bdc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            bdc.clear();
            bdc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var bx = bbW / 2;
            bdc.drawText(bx - 2, 0, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
            bdc.drawText(bx + 2, 0, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
            bdc.drawText(bx - 1, 0, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
            bdc.drawText(bx + 1, 0, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
            bdc.drawText(bx,     0, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER);

            // Scale Y by 1.15 (width unchanged), keep vertical center the same
            var xform = new Graphics.AffineTransform();
            xform.scale(1.0f, 1.15f);
            var scaledH = (tH * 1.15f).toNumber();
            var drawX = cx - bbW / 2;
            var drawY = timeY + tH / 2 - scaledH / 2;
            dc.drawBitmap2(drawX, drawY, bb, {:transform => xform});
        } else {
            // Fallback: bold only, no vertical stretch
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - 2, timeY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx + 2, timeY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx - 1, timeY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx + 1, timeY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx,     timeY, timeFont, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── DAY / DATE circle (right) ────────────────────────────────────
        // Use FORMAT_SHORT to get numeric day_of_week (1=Sun ... 7=Sat)
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayNum = now.day_of_week as Lang.Number;
        var dayNames = ["", "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        var dayStr = dayNum >= 1 && dayNum <= 7 ? dayNames[dayNum] : "---";
        var dateStr = now.day.toString();

        var circX = 385;
        var circY = 170;
        var circR = 42;

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(circX, circY, circR);

        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(circX, circY, circR);

        dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(circX, circY - 20, Graphics.FONT_TINY, dayStr, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(circX, circY - 2, Graphics.FONT_SMALL, dateStr, Graphics.TEXT_JUSTIFY_CENTER);

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

        // Fill proportional to charge (guard against width < 1)
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
