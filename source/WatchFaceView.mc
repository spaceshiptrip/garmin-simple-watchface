import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.ActivityMonitor;
import Toybox.Time;
import Toybox.Time.Gregorian;

// ═══════════════════════════════════════════════════════════════════════════
//  Polished Dark Watch Face — epix2pro 51mm (454 × 454 px)
//
//  Design:
//   • Deep navy/black background with subtle inner-ring accent
//   • Hours in electric blue, minutes in near-white — large, two-tone
//   • Date in a rounded badge (top-right quadrant)
//   • Steps with footstep icon (top-left quadrant)
//   • Battery as a curved arc at the bottom + % label
//   • Tick marks drawn around the bezel rim
//   • AOD: dimmed mono time with orbital burn-in drift
// ═══════════════════════════════════════════════════════════════════════════

class WatchFaceView extends WatchUi.WatchFace {

    // ── Display constants ─────────────────────────────────────────────────
    // epix2pro 51mm screen is 454 × 454 px
    const W  = 454;
    const H  = 454;
    const CX = 227;   // screen center X
    const CY = 227;   // screen center Y
    const R  = 227;   // usable radius to edge

    // ── Color palette (0xRRGGBB) ──────────────────────────────────────────
    // Backgrounds
    const COL_BG_DEEP   = 0x080B12;   // near-black navy
    const COL_BG_PANEL  = 0x0E1520;   // slightly lighter panel for widgets
    const COL_RING_DIM  = 0x1A2030;   // inner ring accent
    const COL_BEZEL_MJ  = 0x2E3340;   // major tick color
    const COL_BEZEL_MN  = 0x1E2535;   // minor tick color

    // Time
    const COL_HH        = 0x2E9AE8;   // electric blue — hours
    const COL_SEP       = 0x1E4A6A;   // dimmed blue — colon
    const COL_MM        = 0xDCE8F5;   // near-white — minutes

    // Date badge
    const COL_DATE_BG   = 0x0E1A30;   // dark badge fill
    const COL_DATE_RING = 0x1A3050;   // badge border
    const COL_DAY_TXT   = 0x4A7AAA;   // muted blue day label
    const COL_DATE_TXT  = 0xDCE8F5;   // bright date number

    // Steps
    const COL_STEPS_IC  = 0x2E9AE8;   // blue icon
    const COL_STEPS_LBL = 0x4A6080;   // muted label
    const COL_STEPS_VAL = 0xA0B4CC;   // lighter value text

    // Battery arc
    const COL_ARC_BG    = 0x141D2C;   // unfilled arc track
    const COL_BATT_OK   = 0x2E9AE8;   // >50% — blue (matches hours)
    const COL_BATT_MID  = 0xF5A623;   // 21–50% — amber
    const COL_BATT_LOW  = 0xE24040;   // ≤20% — red
    const COL_BATT_TXT  = 0x8090A8;   // "BATT" label

    // Divider lines
    const COL_DIV       = 0x141D2C;

    // AOD
    const AOD_BG        = Graphics.COLOR_BLACK;
    const AOD_HH        = 0x444455;
    const AOD_SEP       = 0x2A2A38;
    const AOD_MM        = 0x555566;
    const AOD_DRIFT_R   = 10;   // burn-in drift radius px

    // ── Time layout ───────────────────────────────────────────────────────
    // Center of the time display — pushed slightly above midscreen so
    // widgets fit above and below
    const TIME_CY       = 210;   // vertical center of scaled time bitmap
    const TIME_SCALE_X  = 1.40f;
    const TIME_SCALE_Y  = 1.80f;

    // AOD scales (smaller to leave burn-in margin)
    const AOD_SCALE_X   = 0.75f;
    const AOD_SCALE_Y   = 1.10f;

    // ── Steps widget (top-left) ───────────────────────────────────────────
    const STEPS_CX      = 100;   // widget center X
    const STEPS_TOP     = 58;    // top of widget area
    const STEPS_ICON_SZ = 22;    // icon bounding height px
    const STEPS_FONT    = Graphics.FONT_SMALL;

    // ── Date badge (top-right) ────────────────────────────────────────────
    const DATE_CX       = 354;   // badge center X
    const DATE_CY       = 90;    // badge center Y
    const DATE_RX       = 46;    // badge half-width
    const DATE_RY       = 38;    // badge half-height
    const DATE_RADIUS   = 10;    // corner radius

    // ── Battery arc (bottom, rainbow / upward-bow) ───────────────────────
    // Garmin angle convention: 0=3-o'clock, CCW = increasing degrees.
    // Center is BELOW the screen so the arc bows UPWARD (like a rainbow).
    //   center (227, 471), radius 106 →
    //   right endpoint ~(317, 415) at 32°
    //   peak          ~(227, 365) at 90°  (top of arc circle)
    //   left endpoint ~(137, 415) at 148°
    // CCW from 32°→90°→148° sweeps upward through the peak. ✓
    const ARC_CX      = 227;    // arc circle center X          <-- tweak me
    const ARC_CY      = 471;    // arc circle center Y (off-screen below) <-- tweak me
    const ARC_R       = 106;    // arc circle radius            <-- tweak me
    const ARC_PEN_W   = 6;      // stroke width (px)           <-- tweak me
    const ARC_START   = 32;     // right endpoint angle        <-- tweak me
    const ARC_END     = 148;    // left  endpoint angle        <-- tweak me

    const BATT_VAL_Y  = 388;    // Y of % value text (inside arc curve) <-- tweak me
    const BATT_LBL_Y  = 408;    // Y of "BATTERY" label        <-- tweak me

    // ── Bezel ticks ───────────────────────────────────────────────────────
    const TICK_R_OUT    = 224;   // outer end of tick
    const TICK_R_MJ_IN  = 210;   // inner end of major tick
    const TICK_R_MN_IN  = 216;   // inner end of minor tick

    // ── State ─────────────────────────────────────────────────────────────
    var isAsleep as Lang.Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }
    function onLayout(dc as Graphics.Dc) as Void {}
    function onShow()  as Void {}
    function onHide()  as Void {}

    function onEnterSleep() as Void {
        isAsleep = true;
        WatchUi.requestUpdate();
    }
    function onExitSleep() as Void {
        isAsleep = false;
        WatchUi.requestUpdate();
    }
    function onPartialUpdate(dc as Graphics.Dc) as Void {
        onUpdate(dc);
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    // Convert clockwise-from-top degrees to standard math radians
    function degToRad(deg as Lang.Float) as Lang.Float {
        return (deg - 90.0f) * Math.PI / 180.0f;
    }

    // Point on a circle: (cx + r*cos(rad), cy + r*sin(rad))
    function circPt(cx as Lang.Number, cy as Lang.Number,
                    r as Lang.Number, rad as Lang.Float) as Lang.Array {
        return [
            (cx + r.toFloat() * Math.cos(rad)).toNumber(),
            (cy + r.toFloat() * Math.sin(rad)).toNumber()
        ];
    }

    // Draw a single bezel tick at angleDeg (0=12, 90=3, 180=6, 270=9)
    function drawTick(dc as Graphics.Dc, angleDeg as Lang.Number,
                      rOut as Lang.Number, rIn as Lang.Number,
                      color as Lang.Number, width as Lang.Number) as Void {
        var rad = degToRad(angleDeg.toFloat());
        var p1  = circPt(CX, CY, rOut, rad);
        var p2  = circPt(CX, CY, rIn,  rad);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(width);
        dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
    }

    // Draw all bezel tick marks (12 major + 12 minor = 24 total, every 15°)
    function drawBezelTicks(dc as Graphics.Dc) as Void {
        for (var i = 0; i < 24; i++) {
            var deg = i * 15;
            if (i % 2 == 0) {
                // Major tick every 30°
                drawTick(dc, deg, TICK_R_OUT, TICK_R_MJ_IN, COL_BEZEL_MJ, 2);
            } else {
                // Minor tick every 15°
                drawTick(dc, deg, TICK_R_OUT, TICK_R_MN_IN, COL_BEZEL_MN, 1);
            }
        }
    }

    // Draw battery arc using dc.drawArc() — a thick stroked arc at the bottom.
    // Garmin drawArc angles: 0=3-o'clock, CCW = increasing degrees.
    // Drawing CCW from ARC_START(214°) to ARC_END(326°) sweeps through
    // 270° (6-o'clock / bottom center). ✓
    function drawBatteryArc(dc as Graphics.Dc, battPct as Lang.Number) as Void {
        // Background track (full arc, dark)
        dc.setColor(COL_ARC_BG, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(ARC_PEN_W);
        dc.drawArc(ARC_CX, ARC_CY, ARC_R,
                   Graphics.ARC_COUNTER_CLOCKWISE,
                   ARC_START, ARC_END);

        // Colored fill proportional to battery level
        if (battPct > 0) {
            var fillColor;
            if (battPct <= 20)      { fillColor = COL_BATT_LOW; }
            else if (battPct <= 50) { fillColor = COL_BATT_MID; }
            else                    { fillColor = COL_BATT_OK;  }

            // Fill anchored at LEFT endpoint (ARC_END=148°), grows rightward.
            // At 100%: fillStart=32° → full arc (32→148° CCW).
            // At  50%: fillStart=90° → left half only (90→148° CCW).
            // At   0%: nothing drawn.
            var sweep      = ARC_END - ARC_START;                 // 116°
            var fillStart  = ARC_END - battPct * sweep / 100;
            dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(ARC_PEN_W);
            dc.drawArc(ARC_CX, ARC_CY, ARC_R,
                       Graphics.ARC_COUNTER_CLOCKWISE,
                       fillStart, ARC_END);
        }
    }

    // Fill rotated ellipse using polygon (footstep shapes)
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

    // Draw two-shoe footstep icon centered at (cx, cy)
    function drawStepsIcon(dc as Graphics.Dc,
                           cx as Lang.Number, cy as Lang.Number,
                           size as Lang.Number, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var sf       = size.toFloat();
        var soleRx   = sf * 0.16f;
        var soleRy   = sf * 0.28f;
        var heelRx   = sf * 0.09f;
        var heelRy   = sf * 0.07f;
        var heelDist = soleRy + sf * 0.05f + heelRy;

        var lAngle = -18.0f;
        var lCosA  = Math.cos(lAngle * Math.PI / 180.0f);
        var lSinA  = Math.sin(lAngle * Math.PI / 180.0f);
        var lx = cx - (sf * 0.20f).toNumber();
        var ly = cy - (sf * 0.18f).toNumber();
        fillOval(dc, lx, ly, soleRx, soleRy, lAngle);
        fillOval(dc, lx + (lSinA * heelDist).toNumber(),
                     ly + (lCosA * heelDist).toNumber(),
                     heelRx, heelRy, lAngle);

        var rAngle = 18.0f;
        var rCosA  = Math.cos(rAngle * Math.PI / 180.0f);
        var rSinA  = Math.sin(rAngle * Math.PI / 180.0f);
        var rx = cx + (sf * 0.20f).toNumber();
        var ry = cy + (sf * 0.18f).toNumber();
        fillOval(dc, rx, ry, soleRx, soleRy, rAngle);
        fillOval(dc, rx + (rSinA * heelDist).toNumber(),
                     ry + (rCosA * heelDist).toNumber(),
                     heelRx, heelRy, rAngle);
    }

    // Bold offset text (left-aligned from x)
    function drawBold(bdc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                      font as Graphics.FontType, str as Lang.String) as Void {
        bdc.drawText(x - 1, y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
        bdc.drawText(x + 1, y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
        bdc.drawText(x,     y, font, str, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Render time via BufferedBitmap (scaled two-tone)
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
        var full   = hhStr + sepStr + mmStr;

        var font = Graphics.FONT_NUMBER_THAI_HOT;

        var fullDims = dc.getTextDimensions(full,   font);
        var hhDims   = dc.getTextDimensions(hhStr,  font);
        var sepDims  = dc.getTextDimensions(sepStr, font);
        var tW   = fullDims[0] as Lang.Number;
        var tH   = fullDims[1] as Lang.Number;
        var hhW  = hhDims[0]   as Lang.Number;
        var sepW = sepDims[0]  as Lang.Number;

        var bbW    = tW + 10;
        var startX = (bbW - tW) / 2;
        var hhX    = startX;
        var sepX   = startX + hhW;
        var mmX    = startX + hhW + sepW;

        var bbRef = Graphics.createBufferedBitmap({:width => bbW, :height => tH});
        var bbRaw = bbRef.get();
        if (!(bbRaw instanceof Graphics.BufferedBitmap)) {
            dc.setColor(colorMM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - tH / 2, font, full, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var bb  = bbRaw as Graphics.BufferedBitmap;
        var bdc = bb.getDc();
        bdc.setColor(bgColor, bgColor);
        bdc.clear();

        bdc.setColor(colorHH, Graphics.COLOR_TRANSPARENT);
        if (bold) { drawBold(bdc, hhX, 0, font, hhStr); }
        else       { bdc.drawText(hhX, 0, font, hhStr, Graphics.TEXT_JUSTIFY_LEFT); }

        bdc.setColor(colorSep, Graphics.COLOR_TRANSPARENT);
        bdc.drawText(sepX, 0, font, sepStr, Graphics.TEXT_JUSTIFY_LEFT);

        bdc.setColor(colorMM, Graphics.COLOR_TRANSPARENT);
        if (bold) { drawBold(bdc, mmX, 0, font, mmStr); }
        else       { bdc.drawText(mmX, 0, font, mmStr, Graphics.TEXT_JUSTIFY_LEFT); }

        var xform   = new Graphics.AffineTransform();
        xform.scale(scaleX, scaleY);
        var scaledW = (bbW * scaleX).toNumber();
        var scaledH = (tH  * scaleY).toNumber();
        dc.drawBitmap2(cx - scaledW / 2, cy - scaledH / 2, bb, {:transform => xform});
    }

    // ── Main draw ─────────────────────────────────────────────────────────
    function onUpdate(dc as Graphics.Dc) as Void {

        if (isAsleep) {
            // ── AOD mode ─────────────────────────────────────────────────
            dc.setColor(AOD_BG, AOD_BG);
            dc.clear();

            var minute = System.getClockTime().min.toFloat();
            var angle  = minute * Math.PI / 30.0f;
            var driftX = (AOD_DRIFT_R.toFloat() * Math.sin(angle)).toNumber();
            var driftY = (AOD_DRIFT_R.toFloat() * Math.cos(angle)).toNumber();

            drawTime(dc,
                     CX + driftX, CY + driftY,
                     AOD_SCALE_X, AOD_SCALE_Y,
                     AOD_HH, AOD_SEP, AOD_MM, AOD_BG,
                     false);
            return;
        }

        // ── Awake mode ────────────────────────────────────────────────────

        // 1) Background fill
        dc.setColor(COL_BG_DEEP, COL_BG_DEEP);
        dc.clear();

        // 2) Inner ring accent (subtle rim inside the bezel)
        dc.setColor(COL_RING_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(CX, CY, R - 8);

        // 3) Bezel tick marks
        drawBezelTicks(dc);

        // 4) Subtle horizontal divider lines (frame the time zone)
        dc.setColor(COL_DIV, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(75, 145, 379, 145);   // above time
        dc.drawLine(75, 295, 379, 295);   // below time (above batt/steps text)

        // 5) TIME — large two-tone, centered just above screen center
        drawTime(dc,
                 CX, TIME_CY,
                 TIME_SCALE_X, TIME_SCALE_Y,
                 COL_HH, COL_SEP, COL_MM, COL_BG_DEEP,
                 true);

        // 6) STEPS widget — top-left
        var steps = 0;
        var actInfo = ActivityMonitor.getInfo();
        if (actInfo != null) {
            var s = actInfo.steps;
            if (s != null) { steps = s; }
        }

        // "STEPS" label
        dc.setColor(COL_STEPS_LBL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(STEPS_CX, STEPS_TOP, Graphics.FONT_XTINY,
                    "STEPS", Graphics.TEXT_JUSTIFY_CENTER);

        // Footstep icon
        var iconY = STEPS_TOP + 18;
        drawStepsIcon(dc, STEPS_CX, iconY, STEPS_ICON_SZ, COL_STEPS_IC);

        // Steps value
        var stepsStr  = steps.toString();
        var stepsDims = dc.getTextDimensions(stepsStr, STEPS_FONT);
        var stepsH    = stepsDims[1] as Lang.Number;
        dc.setColor(COL_STEPS_VAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(STEPS_CX, iconY + STEPS_ICON_SZ / 2 + 4,
                    STEPS_FONT, stepsStr, Graphics.TEXT_JUSTIFY_CENTER);

        // 7) DATE badge — top-right, rounded rectangle
        var now      = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayNum   = now.day_of_week as Lang.Number;
        var dayNames = ["", "SU", "MO", "TU", "WE", "TH", "FR", "SA"];
        var dayStr   = (dayNum >= 1 && dayNum <= 7) ? dayNames[dayNum] : "--";
        var dateStr  = now.day.toString();

        // Badge fill
        dc.setColor(COL_DATE_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(DATE_CX - DATE_RX, DATE_CY - DATE_RY,
                                DATE_RX * 2, DATE_RY * 2, DATE_RADIUS);
        // Badge border
        dc.setColor(COL_DATE_RING, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(DATE_CX - DATE_RX, DATE_CY - DATE_RY,
                                DATE_RX * 2, DATE_RY * 2, DATE_RADIUS);

        // Day abbreviation (e.g. "SA") — muted blue, small
        var dayH  = dc.getTextDimensions(dayStr,  Graphics.FONT_XTINY)[1]  as Lang.Number;
        var dateH = dc.getTextDimensions(dateStr, Graphics.FONT_MEDIUM)[1] as Lang.Number;
        var gap   = 1;
        var blockH   = dayH + gap + dateH;
        var blockTop = DATE_CY - blockH / 2;

        dc.setColor(COL_DAY_TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(DATE_CX, blockTop, Graphics.FONT_XTINY,
                    dayStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(COL_DATE_TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(DATE_CX, blockTop + dayH + gap, Graphics.FONT_MEDIUM,
                    dateStr, Graphics.TEXT_JUSTIFY_CENTER);

        // 8) BATTERY arc
        var sysStats = System.getSystemStats();
        var batt     = sysStats.battery.toNumber();
        drawBatteryArc(dc, batt);

        // Battery % value
        var battColor;
        if (batt <= 20)      { battColor = COL_BATT_LOW; }
        else if (batt <= 50) { battColor = COL_BATT_MID; }
        else                 { battColor = COL_BATT_OK;  }

        dc.setColor(battColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ARC_CX, BATT_VAL_Y, Graphics.FONT_SMALL,
                    batt.toString() + "%", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(COL_BATT_TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ARC_CX, BATT_LBL_Y, Graphics.FONT_XTINY,
                    "BATTERY", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
