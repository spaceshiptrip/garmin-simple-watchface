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

    // Background color (awake mode)
    const BG_COLOR = Graphics.COLOR_WHITE; // background    <-- tweak me

    // Time digit colors (awake mode, 0xRRGGBB)
    const TIME_COLOR_HH  = Graphics.COLOR_BLUE;  // hours color   <-- tweak me
    const TIME_COLOR_SEP = 0x888888;              // colon color   <-- tweak me
    const TIME_COLOR_MM  = Graphics.COLOR_BLACK;  // minutes color <-- tweak me

    // Steps display
    const STEPS_X          = 45;                  // left edge X (px)      <-- tweak me
    const STEPS_Y          = 28;                  // top edge Y (px)       <-- tweak me
    const STEPS_ICON_SIZE  = 28;                  // icon height (px)      <-- tweak me
    const STEPS_ICON_COLOR = 0xAAAAAA;            // icon color            <-- tweak me
    const STEPS_TEXT_COLOR = 0xAAAAAA;            // number color          <-- tweak me
    const STEPS_FONT = Graphics.FONT_NUMBER_MEDIUM; // FONT_XTINY/TINY/SMALL/MEDIUM/LARGE <-- tweak me

    // Date circle
    const CIRC_X         = 350;                  // center X                              <-- tweak me
    const CIRC_Y         = 87;                  // center Y                              <-- tweak me
    const CIRC_R         = 60;                   // radius (px)                           <-- tweak me
    const CIRC_DAY_FONT  = Graphics.FONT_XTINY;  // day label font (FONT_XTINY/TINY/SMALL)<-- tweak me
    const CIRC_DATE_FONT = Graphics.FONT_MEDIUM;  // date number font (FONT_TINY/SMALL/MEDIUM)<-- tweak me

    // Battery widget (icon on top, % text below, centered at BATT_X)
    const BATT_X         = 227;                  // center X (px)         <-- tweak me
    //const BATT_Y         = 392;                  // top Y of icon (px)    <-- tweak me
    const BATT_Y         = 372;                  // top Y of icon (px)    <-- tweak me
    const BATT_W         = 44;                   // icon width (px)       <-- tweak me
    const BATT_H         = 18;                   // icon height (px)      <-- tweak me
    const BATT_FONT      = Graphics.FONT_LARGE;   // % text font           <-- tweak me
    const BATT_OK_COLOR  = 0x00CC44;             // > 50% color           <-- tweak me
    const BATT_MID_COLOR = Graphics.COLOR_YELLOW;// 21–50% color          <-- tweak me
    const BATT_LOW_COLOR = Graphics.COLOR_RED;   // ≤ 20% color           <-- tweak me

    // AOD (always-on display) settings
    const AOD_BG_COLOR  = Graphics.COLOR_BLACK; // background    <-- tweak me
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

    // Fill a rotated ellipse using a 12-point polygon approximation.
    // rx, ry = radii (float); angleDeg = clockwise rotation from vertical (float).
    function fillOval(dc as Graphics.Dc,
                      cx as Lang.Number, cy as Lang.Number,
                      rx as Lang.Float, ry as Lang.Float,
                      angleDeg as Lang.Float) as Void {
        var theta = angleDeg * Math.PI / 180.0f;
        var cosA  = Math.cos(theta);
        var sinA  = Math.sin(theta);
        var nPts  = 12;
        var pts   = new [nPts];
        for (var i = 0; i < nPts; i++) {
            var t  = i.toFloat() * 2.0f * Math.PI / nPts.toFloat();
            var ex = rx * Math.cos(t);
            var ey = ry * Math.sin(t);
            pts[i] = [
                (cx + ex * cosA - ey * sinA).toNumber(),
                (cy + ex * sinA + ey * cosA).toNumber()
            ];
        }
        dc.fillPolygon(pts);
    }

    // Draw two shoe-print footsteps icon centered at (cx, cy).
    // size controls overall height; color is the fill color.
    function drawStepsIcon(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number,
                           size as Lang.Number, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var sf = size.toFloat();

        // Shoe sole proportions (as fractions of size)
        var soleRx  = sf * 0.16f;   // sole half-width
        var soleRy  = sf * 0.28f;   // sole half-height
        var heelRx  = sf * 0.09f;   // heel half-width
        var heelRy  = sf * 0.07f;   // heel half-height
        // Distance from sole center to heel center along the shoe axis
        var heelDist = soleRy + sf * 0.05f + heelRy;

        // Left shoe — upper-left, tilted -18° (leans left)
        var lAngle = -18.0f;
        var lCosA  = Math.cos(lAngle * Math.PI / 180.0f);
        var lSinA  = Math.sin(lAngle * Math.PI / 180.0f);
        var lx = cx - (sf * 0.20f).toNumber();
        var ly = cy - (sf * 0.18f).toNumber();
        fillOval(dc, lx, ly, soleRx, soleRy, lAngle);
        // Heel follows the shoe axis downward
        var lhx = lx + (lSinA * heelDist).toNumber();
        var lhy = ly + (lCosA * heelDist).toNumber();
        fillOval(dc, lhx, lhy, heelRx, heelRy, lAngle);

        // Right shoe — lower-right, tilted +18° (leans right)
        var rAngle = 18.0f;
        var rCosA  = Math.cos(rAngle * Math.PI / 180.0f);
        var rSinA  = Math.sin(rAngle * Math.PI / 180.0f);
        var rx = cx + (sf * 0.20f).toNumber();
        var ry = cy + (sf * 0.18f).toNumber();
        fillOval(dc, rx, ry, soleRx, soleRy, rAngle);
        var rhx = rx + (rSinA * heelDist).toNumber();
        var rhy = ry + (rCosA * heelDist).toNumber();
        fillOval(dc, rhx, rhy, heelRx, heelRy, rAngle);
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
                      colorMM as Lang.Number, bgColor as Lang.Number,
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
        bdc.setColor(bgColor, bgColor);
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

        if (isAsleep) {
            // ── AOD mode: time only, dimmer, drifted to prevent burn-in ──
            dc.setColor(AOD_BG_COLOR, AOD_BG_COLOR);
            dc.clear();

            var minute = System.getClockTime().min.toFloat();
            var angle  = minute * Math.PI / 30.0f;   // 0..2π over 60 min
            var driftX = (AOD_DRIFT_R.toFloat() * Math.sin(angle)).toNumber();
            var driftY = (AOD_DRIFT_R.toFloat() * Math.cos(angle)).toNumber();

            drawTime(dc,
                     cx + driftX, cy + driftY,
                     AOD_SCALE_X, AOD_SCALE_Y,
                     AOD_COLOR_HH, AOD_COLOR_SEP, AOD_COLOR_MM, AOD_BG_COLOR,
                     false);
        } else {
            // ── Awake mode: full watch face ──────────────────────────────
            dc.setColor(BG_COLOR, BG_COLOR);
            dc.clear();

            // TIME (drawn first so other elements render on top)
            drawTime(dc,
                     cx, 155 + (dc.getTextDimensions("00:00", Graphics.FONT_NUMBER_THAI_HOT)[1] as Lang.Number) / 2,
                     TIME_SCALE_X, TIME_SCALE_Y,
                     TIME_COLOR_HH, TIME_COLOR_SEP, TIME_COLOR_MM, BG_COLOR,
                     true);

            // STEPS (drawn after time so it sits on top)
            var steps = 0;
            var actInfo = ActivityMonitor.getInfo();
            if (actInfo != null) {
                var s = actInfo.steps;
                if (s != null) { steps = s; }
            }
            var stepsStr   = steps.toString();
            var stepsDims  = dc.getTextDimensions(stepsStr, STEPS_FONT);
            var stepsTextH = stepsDims[1] as Lang.Number;
            var iconGap    = 4;
            var rowH       = stepsTextH > STEPS_ICON_SIZE ? stepsTextH : STEPS_ICON_SIZE;
            var rowCy      = STEPS_Y + rowH / 2;  // vertical center of the row

            drawStepsIcon(dc, STEPS_X + STEPS_ICON_SIZE / 2, rowCy,
                          STEPS_ICON_SIZE, STEPS_ICON_COLOR);

            dc.setColor(STEPS_TEXT_COLOR, Graphics.COLOR_TRANSPARENT);
            dc.drawText(STEPS_X + STEPS_ICON_SIZE + iconGap,
                        rowCy - stepsTextH / 2,
                        STEPS_FONT, stepsStr, Graphics.TEXT_JUSTIFY_LEFT);

            // DAY / DATE circle
            var now    = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var dayNum = now.day_of_week as Lang.Number;
            var dayNames = ["", "SU", "MO", "TU", "WE", "TH", "FR", "SA"];
            var dayStr  = dayNum >= 1 && dayNum <= 7 ? dayNames[dayNum] : "--";
            var dateStr = now.day.toString();
            dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(CIRC_X, CIRC_Y, CIRC_R);
            dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawCircle(CIRC_X, CIRC_Y, CIRC_R);
            // Center both labels together vertically and horizontally in the circle
            var dayH  = dc.getTextDimensions(dayStr,  CIRC_DAY_FONT)[1]  as Lang.Number;
            var dateH = dc.getTextDimensions(dateStr, CIRC_DATE_FONT)[1] as Lang.Number;
            var gap   = 2;
            var blockH = dayH + gap + dateH;
            var blockTop = CIRC_Y - blockH / 2;

            dc.setColor(0x0099FF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CIRC_X, blockTop, CIRC_DAY_FONT, dayStr, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(CIRC_X, blockTop + dayH + gap, CIRC_DATE_FONT, dateStr, Graphics.TEXT_JUSTIFY_CENTER);

            // BATTERY — icon centered at BATT_X, text below
            var sysStats  = System.getSystemStats();
            var batt      = sysStats.battery.toNumber();
            var battColor;
            if (batt <= 20) {
                battColor = BATT_LOW_COLOR;
            } else if (batt <= 50) {
                battColor = BATT_MID_COLOR;
            } else {
                battColor = BATT_OK_COLOR;
            }

            var bx    = BATT_X - BATT_W / 2;
            var nubW  = 4;
            var nubH  = BATT_H / 2;
            var fillW = BATT_W * batt / 100;
            if (fillW < 1) { fillW = 1; }

            // Charge fill
            dc.setColor(battColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx + 1, BATT_Y + 1, fillW - 1, BATT_H - 2);

            // Outline + nub
            dc.setPenWidth(1);
            dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(bx, BATT_Y, BATT_W, BATT_H);
            dc.fillRectangle(bx + BATT_W, BATT_Y + (BATT_H - nubH) / 2, nubW, nubH);

            // Percentage text centered below icon
            dc.setColor(battColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(BATT_X, BATT_Y + BATT_H + 4, BATT_FONT,
                        batt.toString() + "%", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
