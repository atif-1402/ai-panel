import "../.."
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    readonly property var colorPalette: [
        "#e4453a", "#f2a33c", "#f7d038", "#8fd14f",
        "#35c3f2", "#3f6df6", "#904ff0", "#e04fd0"
    ]
    readonly property int cols: 6
    readonly property int rows: 3
    readonly property url dvdSource: Qt.resolvedUrl("../../assets/easteregg/omarchy-dvd.png")
    readonly property url revealSource: Qt.resolvedUrl("../../assets/easteregg/revealing.png")
    readonly property url shipSource: Qt.resolvedUrl("../../assets/easteregg/spaceship.png")
    readonly property url blastSource: Qt.resolvedUrl("../../assets/easteregg/blast.png")
    property int colorIndex: 0
    property string phase: "bounce"
    property int clickCount: 0
    property bool shattered: false
    property real velocityX: 200
    property real velocityY: 150
    property real logoX: 0
    property real logoY: 0
    readonly property real logoWidth: Math.max(220, Math.min(500, screen.width * 0.16))
    readonly property real revealWidth: Math.min(520, screen.width * 0.32)
    readonly property real revealHeight: revealWidth * 92 / 521
    readonly property real srcW: dvdImage.sourceSize.width || 1366
    readonly property real srcH: dvdImage.sourceSize.height || 392
    readonly property real srcCellW: srcW / cols
    readonly property real srcCellH: srcH / rows
    readonly property real logoHeight: logoWidth * srcH / srcW
    readonly property real cellW: logoWidth / cols
    readonly property real cellH: logoHeight / rows
    readonly property int rCols: 8
    readonly property int rRows: 3
    readonly property real rSrcW: revealProbe.sourceSize.width || 521
    readonly property real rSrcH: revealProbe.sourceSize.height || 92
    readonly property real rSrcCellW: rSrcW / rCols
    readonly property real rSrcCellH: rSrcH / rRows
    readonly property real rCellW: revealWidth / rCols
    readonly property real rCellH: revealHeight / rRows
    property int hp: 6
    property int hits: 0
    property real lastHitMs: 0
    property real joltX: 0
    property real joltY: 0
    property bool mouseHeld: false
    property real aimX: screen.width / 2
    readonly property real shipWidth: Math.max(70, Math.min(130, screen.width * 0.055))
    readonly property real shipRailY: screen.height - shipWidth - 28

    function reset() {
        phase = "bounce";
        clickCount = 0;
        shattered = false;
        colorIndex = Math.floor(Math.random() * colorPalette.length);
        const maxX = Math.max(0, screen.width - logoWidth);
        const maxY = Math.max(0, screen.height - logoHeight);
        logoX = Math.random() * maxX;
        logoY = Math.random() * maxY;
        velocityX = (Math.random() < 0.5 ? -1 : 1) * screen.width / 8;
        velocityY = (Math.random() < 0.5 ? -1 : 1) * screen.height / 5.5;
        for (let i = 0; i < fragRepeater.count; i++) {
            const t = fragRepeater.itemAt(i);
            if (!t)
                continue;
            if (t.parent !== dvdWrapper)
                t.parent = dvdWrapper;
            t.freed = false;
            t.dead = false;
            t.vx = 0;
            t.vy = 0;
            t.vrot = 0;
            t.rotation = 0;
            t.opacity = 1;
            t.x = t.col * cellW;
            t.y = t.row * cellH;
            t.visible = true;
        }
        for (let b = bulletLayer.children.length - 1; b >= 0; b--)
            bulletLayer.children[b].destroy();
        for (let bl = blastLayer.children.length - 1; bl >= 0; bl--)
            blastLayer.children[bl].destroy();
        hp = 6;
        hits = 0;
        lastHitMs = 0;
        joltX = 0;
        joltY = 0;
        mouseHeld = false;
        aimX = screen.width / 2;
        ship.x = screen.width / 2 - shipWidth / 2;
        ship.y = screen.height + 90;
        ship.rotation = 0;
        revealGroup.visible = false;
        revealGroup.opacity = 1;
        for (let r = 0; r < fragRepeaterR.count; r++) {
            const rt = fragRepeaterR.itemAt(r);
            if (!rt)
                continue;
            if (rt.parent !== revealGroup)
                rt.parent = revealGroup;
            rt.freed = false;
            rt.dead = false;
            rt.vx = 0;
            rt.vy = 0;
            rt.vrot = 0;
            rt.rotation = 0;
            rt.opacity = 1;
            rt.x = rt.rcol * rCellW;
            rt.y = rt.rrow * rCellH;
            rt.visible = true;
        }
        rCopyR.opacity = 0;
        rCopyG.opacity = 0;
        rCopyB.opacity = 0;
        flashCopy.opacity = 0;
        fireTimer.stop();
        glitchTimer.stop();
        deathSeqTimer.stop();
        deathDelayTimer.stop();
    }

    function advanceColor() {
        colorIndex = (colorIndex + 1) % colorPalette.length;
    }

    function srcRect(col, row) {
        const x0 = Math.max(0, col * srcCellW - 1);
        const y0 = Math.max(0, row * srcCellH - 1);
        return Qt.rect(x0, y0, Math.min(srcW - x0, srcCellW + 2), Math.min(srcH - y0, srcCellH + 2));
    }

    function freeTile(t, fromX, fromY, boost) {
        const cx = t.x + t.width / 2;
        const cy = t.y + t.height / 2;
        let dx = cx - fromX;
        let dy = cy - fromY;
        const dist = Math.max(20, Math.hypot(dx, dy));
        dx /= dist;
        dy /= dist;
        const worldPos = t.mapToItem(dvdWrapper.parent, 0, 0);
        t.parent = dvdWrapper.parent;
        t.x = worldPos.x;
        t.y = worldPos.y;
        t.freed = true;
        const speed = (260 + Math.random() * 220) * boost;
        t.vx = dx * speed + (Math.random() - 0.5) * 120;
        t.vy = dy * speed - 120 * Math.random();
        t.vrot = (Math.random() < 0.5 ? -1 : 1) * (180 + Math.random() * 360);
    }

    function chipOff(px, py, count) {
        const candidates = [];
        for (let i = 0; i < fragRepeater.count; i++) {
            const t = fragRepeater.itemAt(i);
            if (!t || t.freed)
                continue;
            const dx = t.x + t.width / 2 - px;
            const dy = t.y + t.height / 2 - py;
            candidates.push({
                tile: t,
                d: dx * dx + dy * dy
            });
        }
        candidates.sort((a, b) => a.d - b.d);
        for (let j = 0; j < Math.min(count, candidates.length); j++)
            freeTile(candidates[j].tile, px, py, 1.0);
    }

    function shatter(px, py) {
        shattered = true;
        for (let i = 0; i < fragRepeater.count; i++) {
            const t = fragRepeater.itemAt(i);
            if (!t || t.freed)
                continue;
            freeTile(t, px, py, 1.5);
        }
        shatterDelayTimer.restart();
    }

    function srcRectR(col, row) {
        const x0 = Math.max(0, col * rSrcCellW - 1);
        const y0 = Math.max(0, row * rSrcCellH - 1);
        return Qt.rect(x0, y0, Math.min(rSrcW - x0, rSrcCellW + 2), Math.min(rSrcH - y0, rSrcCellH + 2));
    }

    function chipReveal(lx, ly, count) {
        const candidates = [];
        for (let i = 0; i < fragRepeaterR.count; i++) {
            const t = fragRepeaterR.itemAt(i);
            if (!t || t.freed)
                continue;
            const dx = t.x + t.width / 2 - lx;
            const dy = t.y + t.height / 2 - ly;
            candidates.push({
                tile: t,
                d: dx * dx + dy * dy
            });
        }
        candidates.sort((a, b) => a.d - b.d);
        for (let j = 0; j < Math.min(count, candidates.length); j++)
            freeTile(candidates[j].tile, lx, ly, 1.1);
    }

    function shatterReveal() {
        const cx = revealGroup.width / 2;
        const cy = revealGroup.height / 2;
        for (let i = 0; i < fragRepeaterR.count; i++) {
            const t = fragRepeaterR.itemAt(i);
            if (!t || t.freed)
                continue;
            freeTile(t, cx, cy, 1.6);
        }
    }

    function gameStart() {
        hp = 5 + Math.floor(Math.random() * 4);
        hits = 0;
    }

    function spawnBlast(cx, cy, size) {
        blastCom.createObject(blastLayer, {
            x: cx - size / 2,
            y: cy - size / 2,
            blastSize: size
        });
    }

    function registerHit(px, py) {
        const now = Date.now();
        if (now - lastHitMs < 220)
            return;
        lastHitMs = now;
        hits++;
        spawnBlast(px, py, Math.min(120, revealWidth * 0.25));
        joltX = (Math.random() - 0.5) * 18;
        joltY = (Math.random() - 0.5) * 10;
        chipReveal(px - revealGroup.x, py - revealGroup.y, 2 + (Math.random() < 0.5 ? 1 : 0));
        revealPunch.restart();
        if (hits >= hp)
            die();
    }

    function die() {
        phase = "death";
        mouseHeld = false;
        fireTimer.stop();
        shatterReveal();
        deathSeqTimer.step = 0;
        deathSeqTimer.restart();
        deathDelayTimer.restart();
    }

    function finish() {
        GlobalStates.dvdActive = false;
    }

    visible: GlobalStates.dvdActive
    onVisibleChanged: {
        if (visible)
            reset();
        else {
            fireTimer.stop();
            glitchTimer.stop();
            deathSeqTimer.stop();
            deathDelayTimer.stop();
        }
    }

    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:dvd"

    mask: Region {
        item: root.phase === "bounce" ? dvdWrapper : gameArea
    }

    FrameAnimation {
        running: root.visible
        onTriggered: {
            if (root.phase === "bounce") {
                const maxX = Math.max(0, root.screen.width - dvdWrapper.width);
                const maxY = Math.max(0, root.screen.height - dvdWrapper.height);
                let nx = dvdWrapper.x + root.velocityX * frameTime;
                let ny = dvdWrapper.y + root.velocityY * frameTime;
                if (nx <= 0) {
                    nx = 0;
                    root.velocityX = Math.abs(root.velocityX);
                    root.advanceColor();
                } else if (nx >= maxX) {
                    nx = maxX;
                    root.velocityX = -Math.abs(root.velocityX);
                    root.advanceColor();
                }
                if (ny <= 0) {
                    ny = 0;
                    root.velocityY = Math.abs(root.velocityY);
                    root.advanceColor();
                } else if (ny >= maxY) {
                    ny = maxY;
                    root.velocityY = -Math.abs(root.velocityY);
                    root.advanceColor();
                }
                dvdWrapper.x = nx;
                dvdWrapper.y = ny;
            }
            for (let i = 0; i < fragRepeater.count; i++) {
                const t = fragRepeater.itemAt(i);
                if (!t || !t.freed || t.dead)
                    continue;
                t.vy += 900 * frameTime;
                t.x += t.vx * frameTime;
                t.y += t.vy * frameTime;
                t.rotation += t.vrot * frameTime;
                t.opacity -= frameTime / 1.1;
                if (t.opacity <= 0) {
                    t.opacity = 0;
                    t.dead = true;
                    t.visible = false;
                }
            }
            for (let ri = 0; ri < fragRepeaterR.count; ri++) {
                const rt = fragRepeaterR.itemAt(ri);
                if (!rt || !rt.freed || rt.dead)
                    continue;
                rt.vy += 900 * frameTime;
                rt.x += rt.vx * frameTime;
                rt.y += rt.vy * frameTime;
                rt.rotation += rt.vrot * frameTime;
                rt.opacity -= frameTime / 1.8;
                if (rt.opacity <= 0) {
                    rt.opacity = 0;
                    rt.dead = true;
                    rt.visible = false;
                }
            }
            if (root.phase === "game") {
                const targetX = root.aimX - ship.width / 2;
                const ease = Math.min(1, frameTime * 11);
                ship.x += (targetX - ship.x) * ease;
                ship.y += (root.shipRailY - ship.y) * Math.min(1, frameTime * 7);
                const tilt = Math.max(-14, Math.min(14, (targetX - ship.x) * 0.06));
                ship.rotation += (tilt - ship.rotation) * ease;
                root.joltX *= Math.max(0, 1 - frameTime * 9);
                root.joltY *= Math.max(0, 1 - frameTime * 9);
            }
            const dead = [];
            const kids = bulletLayer.children;
            for (let k = kids.length - 1; k >= 0; k--) {
                const bullet = kids[k];
                bullet.y -= 900 * frameTime;
                if (root.phase === "game") {
                    const bx = bullet.x + bullet.width / 2;
                    const by = bullet.y + bullet.height / 2;
                    if (bx >= revealGroup.x - 6 && bx <= revealGroup.x + revealGroup.width + 6 && by >= revealGroup.y - 6 && by <= revealGroup.y + revealGroup.height + 6) {
                        dead.push(bullet);
                        root.registerHit(bx, by);
                        continue;
                    }
                }
                if (bullet.y < -24)
                    dead.push(bullet);
            }
            for (let d = 0; d < dead.length; d++)
                dead[d].destroy();
        }
    }

    Timer {
        id: shatterDelayTimer
        interval: 500
        onTriggered: {
            root.phase = "reveal";
            revealGroup.visible = true;
            glitchTimer.ticks = 0;
            glitchTimer.restart();
        }
    }

    Timer {
        id: glitchTimer
        interval: 45
        repeat: true
        property int ticks: 0
        onTriggered: {
            ticks++;
            if (ticks >= 13) {
                stop();
                rCopyR.opacity = 0;
                rCopyG.opacity = 0;
                rCopyB.opacity = 0;
                flashCopy.opacity = 0;
                revealGroup.opacity = 1;
                root.phase = "game";
                root.gameStart();
                return;
            }
            const roll = Math.random();
            rCopyR.opacity = roll < 0.75 ? 0.85 : 0;
            rCopyG.opacity = roll < 0.5 ? 0.85 : 0;
            rCopyB.opacity = roll < 0.65 ? 0.85 : 0;
            rCopyR.x = (Math.random() - 0.5) * 24;
            rCopyG.x = (Math.random() - 0.5) * 24;
            rCopyB.x = (Math.random() - 0.5) * 24;
            revealGroup.opacity = Math.random() < 0.5 ? 1 : 0.3;
            flashCopy.opacity = Math.random() < 0.12 ? 0.9 : 0;
        }
    }

    Timer {
        id: fireTimer
        interval: 250
        repeat: true
        running: root.visible && root.mouseHeld && root.phase === "game"
        onTriggered: {
            bulletCom.createObject(bulletLayer, {
                x: ship.x + ship.width / 2 - 2,
                y: ship.y - 16
            });
        }
    }

    Timer {
        id: deathSeqTimer
        interval: 170
        repeat: true
        property int step: 0
        onTriggered: {
            step++;
            const cx = revealGroup.x + revealGroup.width / 2;
            const cy = revealGroup.y + revealGroup.height / 2;
            if (step === 1) {
                root.spawnBlast(cx, cy, root.revealWidth * 0.8);
            } else if (step === 2) {
                root.spawnBlast(cx - root.revealWidth * 0.32, cy, root.revealWidth * 0.65);
                root.spawnBlast(cx + root.revealWidth * 0.32, cy, root.revealWidth * 0.65);
            } else if (step === 3) {
                root.spawnBlast(cx, cy, root.revealWidth * 1.6);
                revealGroup.visible = false;
            } else {
                stop();
            }
        }
    }

    Timer {
        id: deathDelayTimer
        interval: 1500
        onTriggered: root.finish()
    }

    component Blast: Image {
        id: blastImg
        property int frame: 0
        property real blastSize: 140
        width: blastSize
        height: blastSize
        source: root.blastSource
        sourceClipRect: Qt.rect((frame % 5) * 192, Math.floor(frame / 5) * 192, 192, 192)
        fillMode: Image.Stretch
        Timer {
            interval: 36
            repeat: true
            running: true
            onTriggered: {
                blastImg.frame++;
                if (blastImg.frame >= 20)
                    blastImg.destroy();
            }
        }
    }

    component Bullet: Rectangle {
        width: 4
        height: 14
        radius: 2
        color: "#ffd48a"
        opacity: 0.95
    }

    Item {
        id: dvdWrapper
        visible: root.phase === "bounce"
        x: root.logoX
        y: root.logoY
        width: root.logoWidth
        height: root.logoHeight

        Image {
            id: dvdImage
            source: root.dvdSource
            visible: false
            width: 0
            height: 0
        }

        Repeater {
            id: fragRepeater
            model: root.cols * root.rows

            Item {
                id: tile
                required property int index
                readonly property int col: index % root.cols
                readonly property int row: Math.floor(index / root.cols)
                property bool freed: false
                property bool dead: false
                property real vx: 0
                property real vy: 0
                property real vrot: 0

                x: col * root.cellW
                y: row * root.cellH
                width: root.cellW
                height: root.cellH
                visible: !dead

                Image {
                    id: tileImage
                    anchors.fill: parent
                    source: root.dvdSource
                    sourceClipRect: root.srcRect(tile.col, tile.row)
                    fillMode: Image.Stretch
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: tileImage
                    colorization: 1.0
                    colorizationColor: root.colorPalette[root.colorIndex]
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (root.shattered)
                    return;
                root.clickCount++;
                punchAnim.restart();
                if (root.clickCount >= 5) {
                    root.shatter(mouse.x, mouse.y);
                } else {
                    root.chipOff(mouse.x, mouse.y, 3 + Math.floor(Math.random() * 2));
                }
            }
        }

        SequentialAnimation {
            id: punchAnim
            NumberAnimation {
                target: dvdWrapper
                property: "scale"
                to: 0.88
                duration: 60
            }
            NumberAnimation {
                target: dvdWrapper
                property: "scale"
                to: 1
                duration: 90
            }
        }
    }

    Image {
        id: revealProbe
        source: root.revealSource
        visible: false
        width: 0
        height: 0
    }

    Item {
        id: revealGroup
        visible: false
        x: (parent.width - width) / 2 + root.joltX
        y: (parent.height - height) / 2 + root.joltY
        width: root.revealWidth
        height: root.revealHeight

        Repeater {
            id: fragRepeaterR
            model: root.rCols * root.rRows

            Item {
                id: rTile
                required property int index
                readonly property int rcol: index % root.rCols
                readonly property int rrow: Math.floor(index / root.rCols)
                property bool freed: false
                property bool dead: false
                property real vx: 0
                property real vy: 0
                property real vrot: 0

                x: rcol * root.rCellW
                y: rrow * root.rCellH
                width: root.rCellW
                height: root.rCellH
                visible: !dead

                Image {
                    id: rTileImage
                    anchors.fill: parent
                    source: root.revealSource
                    sourceClipRect: root.srcRectR(rTile.rcol, rTile.rrow)
                    fillMode: Image.Stretch
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: rTileImage
                }
            }
        }

        Image {
            id: rCopyR
            x: 0
            y: 0
            width: parent.width
            height: parent.height
            source: root.revealSource
            fillMode: Image.Stretch
            visible: opacity > 0
            z: 10
        }

        MultiEffect {
            anchors.fill: parent
            source: rCopyR
            colorization: 1.0
            colorizationColor: "#ff3050"
            z: 10
        }

        Image {
            id: rCopyG
            x: 0
            y: 0
            width: parent.width
            height: parent.height
            source: root.revealSource
            fillMode: Image.Stretch
            visible: opacity > 0
            z: 10
        }

        MultiEffect {
            anchors.fill: parent
            source: rCopyG
            colorization: 1.0
            colorizationColor: "#2bff80"
            z: 10
        }

        Image {
            id: rCopyB
            x: 0
            y: 0
            width: parent.width
            height: parent.height
            source: root.revealSource
            fillMode: Image.Stretch
            visible: opacity > 0
            z: 10
        }

        MultiEffect {
            anchors.fill: parent
            source: rCopyB
            colorization: 1.0
            colorizationColor: "#3a7cff"
            z: 10
        }

        Image {
            id: flashCopy
            anchors.fill: parent
            source: root.revealSource
            fillMode: Image.Stretch
            visible: opacity > 0
            z: 11
        }

        MultiEffect {
            anchors.fill: parent
            source: flashCopy
            colorization: 1.0
            colorizationColor: "#ffffff"
            z: 11
        }

        SequentialAnimation {
            id: revealPunch
            NumberAnimation {
                target: revealGroup
                property: "scale"
                to: 1.07
                duration: 55
            }
            NumberAnimation {
                target: revealGroup
                property: "scale"
                to: 1
                duration: 85
            }
        }
    }

    Image {
        id: ship
        source: root.shipSource
        width: root.shipWidth
        height: width
        x: root.screen.width / 2 - width / 2
        y: root.screen.height + 90
        fillMode: Image.Stretch
    }

    Item {
        id: bulletLayer
        anchors.fill: parent
    }

    Item {
        id: blastLayer
        anchors.fill: parent
    }

    MouseArea {
        id: gameArea
        anchors.fill: parent
        enabled: root.phase === "game"
        hoverEnabled: true
        cursorShape: root.phase === "game" ? Qt.BlankCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPositionChanged: (mouse) => root.aimX = mouse.x
        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.finish();
                return;
            }
            root.aimX = mouse.x;
            root.mouseHeld = true;
            bulletCom.createObject(bulletLayer, {
                x: ship.x + ship.width / 2 - 2,
                y: ship.y - 16
            });
        }
        onReleased: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                root.mouseHeld = false;
        }
    }

    Component {
        id: bulletCom
        Bullet {}
    }

    Component {
        id: blastCom
        Blast {}
    }
}
