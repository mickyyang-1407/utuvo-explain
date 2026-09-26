import "./index.css";
import { Composition, Still } from "remotion";
import { Cover } from "./Cover";
import timeline from "./timeline.json";
import { Tutorial } from "./Tutorial";

export const RemotionRoot: React.FC = () => (
  <>
    <Still id="Cover" component={Cover} width={1080} height={1920} />
    <Composition id="Tutorial" component={Tutorial} durationInFrames={timeline.frames} fps={timeline.fps} width={1920} height={1080} />
    <Composition id="TutorialVertical" component={Tutorial} durationInFrames={timeline.frames} fps={timeline.fps} width={1080} height={1920} />
  </>
);
