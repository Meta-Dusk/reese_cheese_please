# Reese Cheese Please

This is a simple camera app made with `Flutter`.
The name "**Reese Cheese Please**" is derived from the name of the person this app is supposed to be for. "**Cheese**" and "**Please**" is up to _interpretation_.

## 📃 Feature List

| Feature | Description |
| ------- | ----------- |
| **Chemical Development Simulation** | Photos don't appear instantly. They fade in over 4 seconds, mimicking the chemical reaction of real film. |
| **Shake to Develop** | Just like the classic trope, shaking the phone (detected via accelerometer) speeds up the photo's development. |
| **Horizon Level Indicator** | A custom-built UI element using the phone's sensors to ensure every shot is perfectly level. |
| **Vintage Processing** | Every photo is processed with a warm, nostalgic tint and framed in a classic thick-bordered Polaroid layout. |
| **Handwritten Notes** | Users can add a "_Permanent Marker_" note to the bottom of their photos before saving. |

## 📁 Installation

Since I do **not** own a developer account for publishing mobile applications, I can only provide the apk for download :)
You can find the downloads if you look to the right under the about section, just under the releases section :D

## 🤔 Usage Instructions

It's just a simple camera app, but just in case you want to know how to use it properly, here are the steps:

* **Tap** the center circle to take a photo.
* **Shake** your phone to make the photo "_develop_" faster.
* **Type** on the bottom of the Polaroid to add your own handwritten message.

## 🛠️ Technical Details

| Detail | Description |
| ------ | ----------- |
| **Language** | Dart / Flutter |
| **Sensors** | Integrated `sensors_plus` for real-time accelerometer tracking and shake detection. |
| **Custom Widgets** | Modular architecture with extracted components for the viewfinder, controls, and overlays. |
| **Image Processing** | Uses `RepaintBoundary` to capture high-fidelity composite images (3.0 pixel ratio) for gallery saving. |
