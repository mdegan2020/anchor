# ANCHOR

ANCHOR is a MATLAB tool for manually selecting complete tiepoints between two large single-channel remote-sensing images.

The app uses three floating windows: one tiepoint table/control window and two reusable image display windows for Image A and Image B. Tiepoints are saved continuously to CSV.

Start the app from MATLAB with:

```matlab
app = anchor.ANCHOR(imageA, imageB);
```

or provide an explicit CSV output path:

```matlab
app = anchor.ANCHOR(imageA, imageB, "tiepoints.csv");
```
