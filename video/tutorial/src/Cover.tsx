import React from "react";
import { AbsoluteFill, Img, staticFile } from "remotion";

const FONT = "'PingFang TC', 'Heiti TC', system-ui, sans-serif";

/** 9:16 cover: big claim plus real screenshots as stickers. */
export const Cover: React.FC = () => (
  <AbsoluteFill style={{ background: "radial-gradient(ellipse at 70% 15%, #3A2A66 0%, #110E18 65%)", fontFamily: FONT }}>
    <div style={{ position: "absolute", top: 140, left: 80, right: 80 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 22 }}>
        <Img src={staticFile("icon.png")} style={{ width: 110, height: 110, borderRadius: 26 }} />
        <div style={{ fontSize: 40, fontWeight: 700, color: "#A39DB3", letterSpacing: 3 }}>UTUVO Explain</div>
      </div>
      <div style={{ marginTop: 50, fontSize: 118, fontWeight: 900, color: "#F6F3EE", lineHeight: 1.12 }}>
        看不懂的外文<br />框起來<span style={{ color: "#FF9F5A" }}>就懂</span>
      </div>
      <div style={{ marginTop: 28, fontSize: 44, fontWeight: 600, color: "#C9C2DA" }}>選字 ⌥D・框選螢幕 ⌥S・Mac 免費</div>
    </div>
    <Img src={staticFile("frame.png")} style={{ position: "absolute", left: 60, top: 860, width: 760, borderRadius: 12,
      transform: "rotate(-3deg)", boxShadow: "0 30px 80px rgba(0,0,0,0.6)" }} />
    <Img src={staticFile("sub-explain-done.png")} style={{ position: "absolute", right: 60, top: 1130, width: 560,
      transform: "rotate(2deg)", filter: "drop-shadow(0 30px 70px rgba(0,0,0,0.7))" }} />
    <div style={{ position: "absolute", bottom: 60, left: 0, right: 0, textAlign: "center", fontSize: 26, color: "#6E6780" }}>
      App 畫面為實際截圖・影片畫面為示範・需自備 Gemini API Key
    </div>
  </AbsoluteFill>
);
