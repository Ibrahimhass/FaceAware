# FaceAware

<img src="https://raw.githubusercontent.com/BeauNouvelle/FaceAware/master/Images/avatarExample.png" width=50%>

Updated version of now read only library [FaceAware](https://github.com/BeauNouvelle/FaceAware). 

Sometimes the aspect ratios of images we need to work with don't quite fit within the confines of our UIImageViews / NSImageViews.

In most cases we can use AspectFill to fit the image to the bounds of a UIImageView / NSImageView without stretching or leaving whitespace, however when it comes to photos of people, it's quite often to have the faces cropped out if they're not perfectly centered.

This is where FaceAware comes in.
It will analyse an image either through `UIImageView`'s `image` property, or one you set using one of the built in functions and focus in on any faces it can find within.

The most common use for FaceAware is with avatars. 

With FaceAware your users will no longer have to crop and adjust their profile pictures.

<img src="https://raw.githubusercontent.com/BeauNouvelle/FaceAware/master/Images/largeExample.jpg" width=50%>

Based on these two older projects:

* [FaceAware](https://github.com/BeauNouvelle/FaceAware)
* [BetterFace-Swift](https://github.com/croath/UIImageView-BetterFace-Swift)
* [FaceAwareFill](https://github.com/Julioacarrettoni/UIImageView_FaceAwareFill)

Both of which don't seem to be maintained anymore.

## Requirements ##
* Swift 5.0
* iOS 8
* macOS 10.10
* Xcode 13

## Installation ##
#### Manual ####
Simply drag `ImageView+FaceAware.swift` into your project. 

## Useage ##
There are a few ways to get your image views focussing in on faces within images.

You can also recieve a callback for when face detection and any image adjustments have been completed by passing in a closure to the `didFocusOnFaces` property.

```swift
someImageView.didFocusOnFaces = {
     print("Did finish focussing")
}
```


#### Interface Builder ####
This is the easiest method and doesn't require writing any code.
The extension makes use of `@IBDesignable` and `@IBInspectable` so you can turn on focusOnFaces from within IB. However you won't actually see the extension working until you run your project.

<img src="https://raw.githubusercontent.com/BeauNouvelle/FaceAware/master/Images/inspectable.png" width=40%>

#### Code ####
You can set `focusOnFaces` to `true`.

```swift
someImageView.focusOnFaces = true
```
Be sure to set this *after* setting your image. If no image is present when this is called, there will be no faces to focus on.

------

Alternatively you can use:

```swift
someImageView.set(image: myImage, focusOnFaces: true)
```
Which elimates the worry of not having an image previously set.

------

You can also recieve a callback for when face detection and any image adjustments have been completed by passing in a closure to the `didFocusOnFaces` property.

```swift
someImageView.didFocusOnFaces = {
     print("Did finish focussing")
}
```

#### Debugging ####
FaceAware now features a debug mode which draws red squares around any detected faces within an image. To enable you can set the `debug` property to true.

```swift
someImageView.debug = true
```

You can also set this flag within interface builder.


## More help? Questions? ##
This is an updated version of [FaceAware](https://github.com/BeauNouvelle/FaceAware) updated the library to support Swift 5 and also added support for `macOS`.

Reach out to me on Twitter [@IbrahimH_ss_n](https://twitter.com/IbrahimH_ss_n)
Also, if you're using this in your project and you like it, please let me know so I can continue working on it!

## Future Plans ##
- [ ] Add support for SPM.
- [ ] Add support for `ImageView` in SwiftUI.
