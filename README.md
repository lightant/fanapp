# 🎙️ Gemma 4 Live Translate

A premium, multimodal live translation application built with Flutter and powered by the **Gemma 4** Large Language Model. This app provides real-time, hands-free audio-to-text translation across multiple languages.

---

## ✨ Key Features

### 📡 Continuous "LIVE" Mode
The centerpiece of the app is the **Live Loop**. When activated, the app continuously listens, translates, and restarts the recording process without any user interaction. Perfect for long conversations.

### 🧠 Intelligent Voice Activity Detection (VAD)
Built-in silence detection allows for natural pacing:
- **Infinite Waiting**: The app waits indefinitely for you to start speaking.
- **Auto-Processing**: It automatically stops and translates once it detects **2 seconds of silence** after you've finished your thought.
- **Smart Slicing**: Ensures sentences aren't cut off mid-word.

### 🪟 Dual-Window Transcription
Keep track of the conversation with two synchronized views:
- **Original Window**: Displays the real-time transcription of the source language.
- **Translation Window**: Displays the high-quality translation in your target language.
- **History Tracking**: Previous sentences are appended to a scrollable history so you never lose context.

### 🗣️ Multilingual TTS (Text-To-Speech)
Integrated voice synthesis allows you to listen to both the original and translated text.
- Supports **Swedish, Japanese, Chinese, Spanish, Korean, Finnish, and English**.
- Language-aware pronunciation for each source window.

### 🏗️ Design & UX
- **Glassmorphic UI**: A modern, dark-mode aesthetic with vibrant accent colors.
- **AppBar Status Center**: Real-time feedback in the App Bar (LISTENING, INITIALIZING) keeps the main windows clean for text.
- **History Management**: A dedicated clear button to wipe the workspace and start fresh.

---

## 📥 Model Download & Transfer

To use the app, you need the **Gemma 4 E2B** model file in the `.litertlm` (LiteRT) format.

### 1. Download the Model
- **Kaggle Models**: [google/gemma-4/litert/e2b](https://www.kaggle.com/models/google/google-gemma-4-e2b-litertlm)
- **Hugging Face**: [google/gemma-4-e2b-it-litertlm](https://huggingface.co/google/gemma-4-e2b-it-litertlm)

### 2. Transfer to Device

#### 🤖 Android
Connect your phone with ADB enabled and run:
```bash
adb push your-model.litertlm /sdcard/Download/
```
Alternately, copy the file to the Phone's **Downloads** or **Documents** folder via USB File Transfer.

#### 🍎 iOS
1. **AirDrop** the `.litertlm` file to your iPhone.
2. Save it to the **Files** app in a location the app can access (Downloads or Documents).

#### 💻 Desktop (macOS/Linux)
Simply place the `.litertlm` file in your system's **Downloads** or **Documents** folder.

---


## 🚀 Building & Running

### Prerequisites
- Flutter SDK (Latest Stable)
- Android Studio / Xcode
- A **Gemma 4** model file in `.litertlm` format.

### Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone git@github.com:lightant/fanapp.git
   cd fan_app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Gemma Model Setup:**
   - The app automatically scans standard folders on startup.
   - Use the **Side-load (📂)** button in the App Bar if you need to select a file manually.

4. **Run the app:**
   ```bash
   # Run on connected device
   flutter run
   ```

---

## 🛠️ Tech Stack
- **Framework**: [Flutter](https://flutter.dev)
- **AI Engine**: [Flutter Gemma](https://pub.dev/packages/flutter_gemma) (Gemma 4 it)
- **Audio Logic**: `record` & `flutter_tts`
- **State Management**: `flutter_riverpod`
- **Typography**: [Google Fonts (Outfit & Inter)](https://fonts.google.com/)

---

## 📖 How to Use

1. **Initialize**: Launch the app and wait for the "Initializing" indicator in the App Bar to disappear.
2. **Select Languages**: Use the bottom buttons to set your **Source** and **Target** languages.
3. **Manual Mode**: Tap the large center Microphone button to record a single sentence.
4. **Live Mode**: Tap the **LIVE** button in the App Bar. Speak naturally; the app will translate every time you pause for 2 seconds and loop back to listening instantly.
5. **Clear Content**: Tap the **Trash Icon (🗑️)** in the top right to clear the history on both windows.
