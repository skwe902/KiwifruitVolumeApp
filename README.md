# Kiwifruit Volume Measuring App

Written by **Andy Kweon** <br />

This project was done during my summer internship as a machine learning intern.

## Aim of the Project:

The aim of the project was to create an ios app that could measure the volume of a kiwifruit just by the user turning on the app and pointing their phone at the fruit. 

The inspiration was from the well-known "measurement" app that Apple has made, which could be downloaded here: https://apps.apple.com/us/app/measure/id1383426740

## Project Outline:
Initially, I have planned the app in three stages:

**Stage 1:** Recreate the measurement app using ARKit framework <br />
**Stage 2:** Implement machine learning using CoreML <br />
**Stage 3:** Utilize Lidar technology <br />

I will explain the implementation in each of these stages and some of the challenges that I have faced in more detail below.

## Stage 1: Basic Measurement App

The measurement app has already been made by quite a lot of people, but the one that I took reference from was this: https://github.com/gualtierofrigerio/SwiftUIARKit

I wanted to use SwiftUI to make the UI instead of Storyboard, just to let the project to be a lot more manageable in the future. 
<p align="center">
<img src = "https://user-images.githubusercontent.com/63220455/144689825-fb27763c-b9fc-4f94-b3dd-b91b90e5eef8.png"> <br />
Fig 1. Screenshot of the Measurement App
</p>
The user would tap on the screen the two points they want to measure the distance across. By using ARKit, it would place the virtual orange circles on the real world and return the real-world 3D co-ordinates. We can then use these co-ordinates to calculate the distance using pythagoras. After getting the width and the length of the kiwifruit, the app automatically estimates the volume by using the volume formula for an ellipsoid.

## Stage 2: Implementing Object Detection

With the measurement app completed, the next stage was to implement an object detection model. The app would automatically detect a kiwifruit, put a bonding box around it, and place the virtual orange circles based on the bounding box co-ordinates. Using the same logic as before, we can get the width and height of the kiwifruit and use it to measure the volume.

<p align="center">
<img src = "https://user-images.githubusercontent.com/63220455/144692225-b1a7bc6b-59ad-4a43-816c-a0bde08315b1.png"> <br />
Fig 2. Making a Core ML model
</p>
 
To allow for seamless integration with the app, the model was trained using Create ML which is already built into XCode. ~100 images from online and taken by myself were labelled and used for training the YOLOv3 model for real-time detection of kiwifruit. 

<p align="center">
<img src = "https://user-images.githubusercontent.com/63220455/144691947-195934a3-149b-41ca-87c1-57d5091d1304.png"> <br />
Fig 3. Implementing Core ML model to the app
</p>

<p align="center">
<img src = "https://user-images.githubusercontent.com/63220455/144691754-74655639-bf01-4aba-8cda-95761cf41616.png"> <br />
Fig 4. Testing the Model on a Previously Unseen Image
</p>

You can see the real-time performance of the model in the video below. The Core ML model was loaded into real-time object detection app found on Apple's developer website: https://developer.apple.com/documentation/vision/recognizing_objects_in_live_capture

https://user-images.githubusercontent.com/63220455/144691141-9dd96010-8575-47f6-8902-08f35396eeb7.mp4

## Stage 3: Utilizing Lidar & depth measurements

## File Description:

## Limitations and Future Works:
