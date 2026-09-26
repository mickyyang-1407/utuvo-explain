import { Audio } from "@remotion/media";
import React from "react";
import {
  AbsoluteFill, Easing, Img, Sequence, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig,
} from "remotion";
import timeline from "./timeline.json";

type Scene = (typeof timeline.scenes)[number];

const C = { bg: "#110E18", card: "#1C1826", stroke: "#2E2940", violet: "#8B6CFF", orange: "#FF9F5A", text: "#F6F3EE", dim: "#A39DB3" };
const FONT = "'PingFang TC', 'Heiti TC', system-ui, sans-serif";
const ease = Easing.bezier(0.16, 1, 0.3, 1);
const steps = timeline.scenes.filter((s) => s.kind !== "title");
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const at = (frame: number, a: number, b: number) => interpolate(frame, [a, b], [0, 1], { ...clamp, easing: ease });

/** Progress bar across the top of the whole video. */
const Progress: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <div style={{ position: "absolute", top: 0, left: 0, height: 6, width: `${(frame / timeline.frames) * 100}%`,
      background: `linear-gradient(90deg, ${C.violet}, ${C.orange})` }} />
  );
};

const Subtitles: React.FC<{ scene: Scene }> = ({ scene }) => {
  const frame = useCurrentFrame();
  const sub = scene.subs.find((s) => frame >= s.from && frame < s.to + 6);
  if (!sub) return null;
  const opacity = interpolate(frame, [sub.from, sub.from + 5], [0, 1], clamp);
  return (
    <div style={{ position: "absolute", left: 0, right: 0, bottom: 72, display: "flex", justifyContent: "center", opacity }}>
      <div style={{ background: "rgba(10,8,16,0.82)", border: `1px solid ${C.stroke}`, borderRadius: 18, padding: "12px 28px",
        color: C.text, fontSize: 40, lineHeight: 1.35, fontWeight: 600, fontFamily: FONT }}>{sub.text}</div>
    </div>
  );
};

const Heading: React.FC<{ scene: Scene }> = ({ scene }) => {
  const frame = useCurrentFrame();
  const step = steps.findIndex((s) => s.id === scene.id) + 1;
  const a = at(frame, 0, 18), b = at(frame, 6, 26);
  return (
    <div style={{ position: "absolute", top: 70, left: 110, fontFamily: FONT }}>
      <div style={{ display: "flex", alignItems: "center", gap: 16, opacity: a, transform: `translateX(${(1 - a) * -40}px)` }}>
        <div style={{ fontSize: 22, fontWeight: 800, color: "#fff", background: C.violet, borderRadius: 8, padding: "4px 12px" }}>
          {String(step).padStart(2, "0")}
        </div>
        <div style={{ fontSize: 22, letterSpacing: 5, color: C.dim, fontWeight: 700 }}>STEP {step} / {steps.length}</div>
      </div>
      <div style={{ marginTop: 16, fontSize: 64, fontWeight: 800, color: C.text, opacity: a, transform: `translateY(${(1 - a) * 24}px)` }}>
        {scene.title}
      </div>
      <div style={{ marginTop: 6, fontSize: 32, fontWeight: 500, color: C.orange, opacity: b }}>{scene.caption}</div>
    </div>
  );
};

/** Keycap that pops in at `from`. */
const KeyCap: React.FC<{ label: string; from: number; x: number; y: number }> = ({ label, from, x, y }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame: frame - from, fps, config: { damping: 12, stiffness: 160 } });
  const press = interpolate(frame, [from + 10, from + 14, from + 20], [1, 0.9, 1], clamp);
  if (frame < from) return null;
  return (
    <div style={{ position: "absolute", left: x, top: y, transform: `scale(${pop * press})`, fontFamily: FONT,
      background: "linear-gradient(#FFFFFF, #E9E4F5)", color: "#3B2A7A", fontSize: 58, fontWeight: 800, padding: "14px 34px",
      borderRadius: 22, boxShadow: "0 10px 0 #B9AEDB, 0 24px 50px rgba(0,0,0,0.45)" }}>{label}</div>
  );
};

/** A real Explain panel screenshot: loading state first, then the result. */
const Panel: React.FC<{ loading: string; done: string; from: number; doneAt: number; x: number; y: number; w?: number }> =
  ({ loading, done, from, doneAt, x, y, w = 560 }) => {
    const frame = useCurrentFrame();
    const { fps } = useVideoConfig();
    const enter = spring({ frame: frame - from, fps, config: { damping: 200 } });
    const swap = interpolate(frame, [doneAt, doneAt + 8], [0, 1], clamp);
    if (frame < from) return null;
    const h = Math.round((w * 864) / 840);
    const shot = (src: string, opacity: number) => (
      <Img src={staticFile(src)} style={{ position: "absolute", inset: 0, width: w, height: h, opacity }} />
    );
    return (
      <div style={{ position: "absolute", left: x, top: y, width: w, height: h, opacity: enter,
        transform: `translateY(${(1 - enter) * 40}px) scale(${0.96 + enter * 0.04})`,
        filter: "drop-shadow(0 30px 60px rgba(0,0,0,0.6))" }}>
        {shot(loading, 1 - swap)}{shot(done, swap)}
      </div>
    );
  };

const SENTENCE = "Lossless streaming preserves every bit of the original master, yet the difference is often masked by the playback chain.";

/** A plain demo web page with the sentence being selected. */
const Article: React.FC<{ select: [number, number] }> = ({ select }) => {
  const frame = useCurrentFrame();
  const p = at(frame, select[0], select[1]);
  const enter = at(frame, 0, 20);
  return (
    <div style={{ position: "absolute", left: 110, top: 290, width: 1000, height: 470, borderRadius: 18, overflow: "hidden",
      background: "#FBF8F3", boxShadow: "0 30px 80px rgba(0,0,0,0.5)", opacity: enter, transform: `translateY(${(1 - enter) * 30}px)`,
      fontFamily: "Georgia, 'Times New Roman', serif" }}>
      <div style={{ height: 46, background: "#E9E4DC", display: "flex", alignItems: "center", gap: 10, padding: "0 18px" }}>
        {["#FF5F57", "#FEBC2E", "#28C840"].map((c) => <div key={c} style={{ width: 13, height: 13, borderRadius: 7, background: c }} />)}
        <div style={{ marginLeft: 18, flex: 1, height: 26, borderRadius: 8, background: "#F7F4EF", color: "#8A847A",
          fontSize: 15, fontFamily: FONT, display: "flex", alignItems: "center", paddingLeft: 14 }}>audio-journal.example/lossless-myths</div>
      </div>
      <div style={{ padding: "40px 56px", color: "#2A2620" }}>
        <div style={{ fontSize: 15, letterSpacing: 3, color: "#A0703F", fontFamily: FONT, fontWeight: 700 }}>LISTENING NOTES</div>
        <div style={{ fontSize: 42, fontWeight: 700, margin: "12px 0 22px", lineHeight: 1.15 }}>Is lossless really worth it?</div>
        <div style={{ fontSize: 25, lineHeight: 1.65, color: "#4A443B" }}>
          Streaming services now offer high-resolution files at no extra cost.{" "}
          <span style={{ backgroundImage: "linear-gradient(rgba(139,108,255,0.38), rgba(139,108,255,0.38))",
            backgroundRepeat: "no-repeat", backgroundSize: `${p * 100}% 100%` }}>{SENTENCE}</span>{" "}
          Before upgrading, listen on the gear you actually use every day.
        </div>
      </div>
    </div>
  );
};

/** The demo video frame with the crosshair dragging a box around the subtitle. */
const Framing: React.FC<{ drag: [number, number] }> = ({ drag }) => {
  const frame = useCurrentFrame();
  const W = 1000, s = W / 1920, H = Math.round(1144 * s);
  const enter = at(frame, 0, 20);
  const box = { x: 280 * s, y: 890 * s, w: 1360 * s, h: 160 * s };
  const p = at(frame, drag[0], drag[1]);
  const moving = at(frame, drag[0] - 24, drag[0]);
  const cx = interpolate(moving, [0, 1], [box.x + 300, box.x]) + box.w * p;
  const cy = interpolate(moving, [0, 1], [box.y - 160, box.y]) + box.h * p;
  const showCross = frame >= drag[0] - 24 && frame < drag[1] + 12;
  return (
    <div style={{ position: "absolute", left: 110, top: 300, width: W, height: H, opacity: enter,
      transform: `translateY(${(1 - enter) * 30}px)`, filter: "drop-shadow(0 30px 70px rgba(0,0,0,0.6))" }}>
      <Img src={staticFile("frame.png")} style={{ width: W, height: H, borderRadius: 12 }} />
      {frame >= drag[0] && frame < drag[1] + 12 && (
        <div style={{ position: "absolute", left: box.x, top: box.y, width: box.w * p, height: box.h * p,
          background: "rgba(255,255,255,0.14)", border: "2px solid #fff" }} />
      )}
      {showCross && (
        <div style={{ position: "absolute", left: cx - 22, top: cy - 22, width: 44, height: 44 }}>
          <div style={{ position: "absolute", left: 21, top: 0, width: 3, height: 44, background: "#fff", boxShadow: "0 0 0 1px #000" }} />
          <div style={{ position: "absolute", top: 21, left: 0, height: 3, width: 44, background: "#fff", boxShadow: "0 0 0 1px #000" }} />
        </div>
      )}
    </div>
  );
};

const Shot: React.FC<{ src: string; from: number; x: number; y: number; w: number; ratio: number }> = ({ src, from, x, y, w, ratio }) => {
  const frame = useCurrentFrame();
  const a = at(frame, from, from + 18);
  if (frame < from) return null;
  return <Img src={staticFile(src)} style={{ position: "absolute", left: x, top: y, width: w, height: Math.round(w * ratio),
    opacity: a, transform: `translateY(${(1 - a) * 30}px)`, filter: "drop-shadow(0 30px 60px rgba(0,0,0,0.55))", borderRadius: 14 }} />;
};

const Bullets: React.FC<{ items: string[]; from: number }> = ({ items, from }) => {
  const frame = useCurrentFrame();
  return (
    <div style={{ position: "absolute", left: 110, top: 330, display: "flex", flexDirection: "column", gap: 26, fontFamily: FONT }}>
      {items.map((t, i) => {
        const a = at(frame, from + i * 40, from + i * 40 + 18);
        return (
          <div key={t} style={{ display: "flex", alignItems: "center", gap: 20, opacity: a, transform: `translateX(${(1 - a) * -30}px)` }}>
            <div style={{ width: 46, height: 46, borderRadius: 23, background: C.violet, color: "#fff", fontSize: 26, fontWeight: 800,
              display: "flex", alignItems: "center", justifyContent: "center" }}>✓</div>
            <div style={{ fontSize: 38, color: C.text, fontWeight: 600 }}>{t}</div>
          </div>
        );
      })}
    </div>
  );
};

const TitleCard: React.FC<{ scene: Scene; outro?: boolean }> = ({ scene, outro }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const pop = spring({ frame, fps, config: { damping: 14, stiffness: 120 } });
  const t = at(frame, 10, 34);
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", fontFamily: FONT }}>
      <Img src={staticFile("icon.png")} style={{ width: 240, height: 240, borderRadius: 54, transform: `scale(${pop})`,
        boxShadow: "0 30px 90px rgba(139,108,255,0.35)" }} />
      <div style={{ marginTop: 44, fontSize: 110, fontWeight: 900, color: C.text, opacity: t, letterSpacing: 6 }}>{scene.title}</div>
      <div style={{ marginTop: 10, fontSize: 40, fontWeight: 600, color: C.orange, opacity: t }}>{scene.caption}</div>
      {outro && (
        <div style={{ marginTop: 50, fontSize: 32, color: C.dim, opacity: t, textAlign: "center", lineHeight: 1.6 }}>
          ⌥D 白話解釋・⌥⇧D 翻譯・⌥S 框選螢幕<br />mickyyang-1407.github.io/utuvo-explain
        </div>
      )}
    </AbsoluteFill>
  );
};

/** Scene layouts. Timings are fractions of the scene so they follow the narration length. */
const Stage: React.FC<{ scene: Scene }> = ({ scene }) => {
  const f = (x: number) => Math.round(scene.frames * x);
  switch (scene.kind) {
    case "setup":
      return (<>
        <Shot src="settings.png" from={f(0.04)} x={110} y={300} w={680} ratio={824 / 1020} />
        <Shot src="tutorial-1.png" from={f(0.55)} x={1000} y={200} w={560} ratio={1304 / 1120} />
      </>);
    case "select":
      return (<>
        <Article select={[f(0.14), f(0.34)]} />
        <KeyCap label="⌥D" from={f(0.38)} x={880} y={200} />
        <Panel loading="art-explain-loading.png" done="art-explain-done.png" from={f(0.46)} doneAt={f(0.6)} x={1200} y={250} />
      </>);
    case "translate":
      return (<>
        <Article select={[-20, -10]} />
        <KeyCap label="⌥⇧D" from={f(0.12)} x={820} y={200} />
        <Panel loading="art-translate-loading.png" done="art-translate-done.png" from={f(0.2)} doneAt={f(0.34)} x={1200} y={250} />
      </>);
    case "frame":
      return (<>
        <Framing drag={[f(0.3), f(0.44)]} />
        <KeyCap label="⌥S" from={f(0.2)} x={980} y={200} />
        <Panel loading="sub-explain-loading.png" done="sub-explain-done.png" from={f(0.5)} doneAt={f(0.66)} x={1220} y={250} />
      </>);
    case "privacy":
      return (<>
        <Bullets items={["文字辨識在 Mac 本機完成", "框選的畫面用完就刪除", "只把辨識出的文字送給 Gemini", "第一次框選：允許螢幕錄製"]} from={f(0.05)} />
        <Shot src="tutorial-4.png" from={f(0.1)} x={1180} y={180} w={560} ratio={1304 / 1120} />
      </>);
    default:
      return null;
  }
};

const SceneView: React.FC<{ scene: Scene }> = ({ scene }) => {
  const frame = useCurrentFrame();
  const fadeOut = interpolate(frame, [scene.frames - 10, scene.frames], [1, 0], clamp);
  const isCard = scene.kind === "title";
  return (
    <AbsoluteFill style={{ opacity: scene.id === "outro" ? 1 : fadeOut }}>
      {isCard ? <TitleCard scene={scene} outro={scene.id === "outro"} /> : (<><Heading scene={scene} /><Stage scene={scene} /></>)}
      <Subtitles scene={scene} />
      <Sequence from={scene.voFrom} layout="none"><Audio src={staticFile(scene.vo)} /></Sequence>
    </AbsoluteFill>
  );
};

export const Tutorial: React.FC = () => (
  <AbsoluteFill style={{ background: `radial-gradient(ellipse at 70% 20%, #2A1F48 0%, ${C.bg} 62%)` }}>
    {timeline.scenes.map((s) => (
      <Sequence key={s.id} from={s.start} durationInFrames={s.frames}><SceneView scene={s as Scene} /></Sequence>
    ))}
    <Progress />
    <div style={{ position: "absolute", bottom: 22, width: "100%", textAlign: "center", fontFamily: FONT, fontSize: 20, color: "#6E6780" }}>
      旁白為 AI 語音生成・App 視窗為實際截圖，選字與框選動作為示意
    </div>
  </AbsoluteFill>
);
