import "./index.css";
import { Composition } from "remotion";
import timeline from "./timeline.json";
import { Tutorial } from "./Tutorial";

export const RemotionRoot: React.FC = () => (
  <Composition id="Tutorial" component={Tutorial} durationInFrames={timeline.frames} fps={timeline.fps} width={1920} height={1080} />
);
