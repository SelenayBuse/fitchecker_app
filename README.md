# fitchecker_app

This Windows/Mobile App is designed for personal use. 

## 🎯 Aim of the App

The goal of the FitChecker App is to provide users with a personal, AI-powered virtual dressing room. It allows users to upload their own photos and visualize how different clothing items (tops, bottoms, and coats) from their wardrobe would look on them.

The application uses Google's powerful Gemini AI model to "dress" the user's photo with the selected garments.

## ✨ Core Features

Virtual Try-On: See how outfits look on your own photo without physically trying them on.

AI-Powered Generation: Uses Google's gemini-2.5-flash-image model to realistically dress the user's image.

AI Stylist (Custom Prompt): Don't know what to wear? Write a prompt (e.g., "a formal office look") and let the AI choose the best combination from your inventory.

Cross-Platform: Built with Flutter to run on both Windows and Mobile (Android/iOS) from a single codebase.

Retro Interface: Features a unique, nostalgic Windows 95 aesthetic, courtesy of the flutter_95 package.

Save & Share: Save your generated outfits directly to a "FitChecker" folder on your device.

## 💡 How It Works (Technical Overview)

The app's workflow revolves around two primary AI functions:

1. Manual Outfit Creation (_createOutfit)
- The user uploads a photo of themselves.

- The user uploads the photos of their garments

- The user selects a specific item from the "Top", "Bottom", and (optional) "Coat" carousels.

- The app sends the user's photo and the 3 selected items (either image data or color info) to the _callGeminiImageApi function.

- The Gemini API takes these specific assets and generates a new image, virtually dressing the user.

2. AI Stylist (_createOutfitFromCustomPrompt)
- The user clicks the "Enter custom prompt" button and types a text request (e.g., "an outfit for a night out").

- The app triggers the _callGeminiImageApiWithPrompt (or a similar) function.

- This function sends a more complex request to the Gemini API, including:
    - The user's photo.
    - The user's text prompt.
    - The entire clothing lists (all available _tops, _bottoms, and _coats).

- The AI is instructed to reason and select the most appropriate items from the provided lists that match the text prompt, and then generate the final image.

- The resulting image is displayed on the screen.

## 🛠️ Tech Stack

Framework: Flutter

Language: Dart

UI Package: flutter_95 (for the Windows 95 aesthetic)

Artificial Intelligence: Google Gemini API (gemini-2.5-flash-image)

API Communication: http

Secret Management: flutter_dotenv

## 🚀 How to Run

1. Clone the repo and download the dependencies. 
    '''
    git clone https://github.com/SelenayBuse/fitchecker_app.git
    cd fitchecker_app
    flutter pub get
    '''
2. Add your own .env file including:
    '''
    REMOVE_BG_API_KEY= your removebg api key
    GOOGLE_API_KEY= your google gemini api key
    '''
3. Run the application using:
    '''
    flutter run -d windows (for windows)
    '''
    or
    '''
    flutter run (for Android Emulator)
    '''

4. Add your garments using the application menu 'Add Clothes'
