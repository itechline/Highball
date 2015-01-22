//
//  PhotosetRowTableViewCell.swift
//  Highball
//
//  Created by Ian Ynda-Hummel on 8/27/14.
//  Copyright (c) 2014 ianynda. All rights reserved.
//

import UIKit

class PhotosetRowTableViewCell: WCFastCell {
    private let imageLoadQueue = dispatch_queue_create("imageLoadQueue", nil)

    var imageViews: Array<FLAnimatedImageView>?
    var shareHandler: ((UIImage) -> ())?
    var imageDownloadOperations: Array<SDWebImageOperation>?
    
    var contentWidth: CGFloat! = 0
    var images: Array<PostPhoto>? {
        didSet {
            dispatch_async(dispatch_get_main_queue(), {
                self.updateImages()
            })
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.clearImages()
    }

    private func updateImages() {
        if let images = self.images {
            if let contentWidth = self.contentWidth {
                self.clearImages()

                let imageManager = SDWebImageManager.sharedManager()
                let imageDownloader = SDWebImageDownloader.sharedDownloader()
                let widthRatio: Float = 1.0 / Float(images.count)
                let lastImageIndex = images.count - 1
                var imageViews = Array<FLAnimatedImageView>()
                var downloadOperations = Array<SDWebImageOperation>()
                var lastImageView: UIImageView?
                for (index, image) in enumerate(images) {
                    let imageView = FLAnimatedImageView()
                    let imageURL = image.urlWithWidth(contentWidth)
                    let cacheKey = imageManager.cacheKeyForURL(imageURL)
                    
                    self.contentView.addSubview(imageView)

                    if let leftImageView = lastImageView {
                        if index == lastImageIndex {
                            layout(imageView, leftImageView, self.contentView) { imageView, leftImageView, contentView in
                                imageView.centerY == leftImageView.centerY
                                imageView.left == leftImageView.right
                                imageView.right == contentView.right
                                imageView.height == leftImageView.height
                            }
                        } else {
                            layout(imageView, leftImageView, self.contentView) { imageView, leftImageView, contentView in
                                imageView.centerY == leftImageView.centerY
                                imageView.left == leftImageView.right
                                imageView.size == leftImageView.size
                            }
                        }
                    } else if images.count == 1 {
                        layout(imageView, self.contentView) { imageView, contentView in
                            imageView.left == contentView.left
                            imageView.top == contentView.top
                            imageView.bottom == contentView.bottom
                            imageView.right == contentView.right
                        }
                    } else {
                        layout(imageView, self.contentView) { imageView, contentView in
                            imageView.left == contentView.left
                            imageView.top == contentView.top
                            imageView.bottom == contentView.bottom
                            imageView.width == contentView.width * widthRatio
                        }
                    }

                    imageView.image = nil
                    imageView.backgroundColor = UIColor.lightGrayColor()
                    imageView.userInteractionEnabled = true
                    imageView.contentMode = UIViewContentMode.ScaleAspectFill

                    if imageURL.pathExtension == "gif" {
                        if let animatedImage = AnimatedImageCache.animatedImageForKey(cacheKey) {
                            imageView.animatedImage = animatedImage
                        } else if let data = TMCache.sharedCache().objectForKey(imageURL.absoluteString) as? NSData {
                            dispatch_async(self.imageLoadQueue, {
                                let animatedImage = FLAnimatedImage(animatedGIFData: data)
                                dispatch_async(dispatch_get_main_queue(), {
                                    AnimatedImageCache.setAnimatedImage(animatedImage, forKey: cacheKey)
                                    imageView.animatedImage = animatedImage
                                })
                            })
                        } else {
                            let imageDownloadOperation = imageDownloader.downloadImageWithURL(imageURL, options: SDWebImageDownloaderOptions.UseNSURLCache, progress: nil, completed: { (image, data, error, finished) -> Void in
                                if finished && error == nil {
                                    dispatch_async(self.imageLoadQueue, {
                                        let animatedImage = FLAnimatedImage(animatedGIFData: data)
                                        dispatch_async(dispatch_get_main_queue(), {
                                            AnimatedImageCache.setAnimatedImage(animatedImage, forKey: cacheKey)
                                            imageView.animatedImage = animatedImage
                                        })
                                    })
                                    TMCache.sharedCache().setObject(data, forKey: imageURL.absoluteString)
                                }
                            })
                            if let operation = imageDownloadOperation {
                                downloadOperations.append(operation)
                            }
                        }
                    } else {
                        imageView.sd_setImageWithURL(imageURL)
                    }
                    
                    lastImageView = imageView

                    imageViews.append(imageView)
                }
                
                self.imageViews = imageViews
                self.imageDownloadOperations = downloadOperations
            }
        }
    }

    private func clearImages() {
        if let imageViews = self.imageViews {
            for imageView in imageViews {
                imageView.sd_cancelCurrentAnimationImagesLoad()
                imageView.sd_cancelCurrentImageLoad()
                imageView.image = nil
                imageView.animatedImage = nil
                imageView.removeFromSuperview()
            }
        }
        
        if let operations = self.imageDownloadOperations {
            for operation in operations {
                operation.cancel()
            }
        }
        
        self.imageViews = nil
        self.imageDownloadOperations = nil
    }

    func imageAtPoint(point: CGPoint) -> UIImage? {
        if let imageView = self.hitTest(point, withEvent: nil) as? UIImageView {
            return imageView.image
        }
        return nil
    }

    func cancelDownloads() {
        self.clearImages()
    }

}
