import {isMas} from './is-mas';

/** H.264 encoder: VideoToolbox on MAS (avoids GPL libx264), libx264 elsewhere. */
export const h264Encoder = (): string => isMas ? 'h264_videotoolbox' : 'libx264';

/** HEVC encoder: VideoToolbox on MAS (avoids GPL libx265), libx265 elsewhere. */
export const hevcEncoder = (): string => isMas ? 'hevc_videotoolbox' : 'libx265';

/** True when GIF post-compression via gifsicle is allowed (not on MAS — GPL). */
export const canUseGifsicle = (): boolean => !isMas;
