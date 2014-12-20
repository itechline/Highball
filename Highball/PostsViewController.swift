//
//  PostsViewController.swift
//  Highball
//
//  Created by Ian Ynda-Hummel on 10/26/14.
//  Copyright (c) 2014 ianynda. All rights reserved.
//

import UIKit

enum TextRow: Int {
    case Title
    case Body
}

enum AnswerRow: Int {
    case Question
    case Answer
}

enum QuoteRow: Int {
    case Quote
    case Source
}

enum LinkRow: Int {
    case Link
    case Description
}

enum VideoRow: Int {
    case Player
    case Caption
}

enum AudioRow: Int {
    case Player
    case Caption
}

let postHeaderViewIdentifier = "postHeaderViewIdentifier"
let titleTableViewCellIdentifier = "titleTableViewCellIdentifier"
let photosetRowTableViewCellIdentifier = "photosetRowTableViewCellIdentifier"
let contentTableViewCellIdentifier = "contentTableViewCellIdentifier"
let postQuestionTableViewCellIdentifier = "postQuestionTableViewCellIdentifier"
let postLinkTableViewCellIdentifier = "postLinkTableViewCellIdentifier"
let postDialogueEntryTableViewCellIdentifier = "postDialogueEntryTableViewCellIdentifier"

class PostsViewController: UIViewController, UIGestureRecognizerDelegate, UITableViewDataSource, UITableViewDelegate, UIViewControllerTransitioningDelegate, UIWebViewDelegate {
    var tableView: UITableView!
    
    private let requiredRefreshDistance: CGFloat = 60
    
    private var longPressGestureRecognizer: UILongPressGestureRecognizer!
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var reblogViewController: QuickReblogViewController?
    
    var bodyWebViewCache: Dictionary<Int, UIWebView>!
    var bodyHeightCache: Dictionary<Int, CGFloat>!
    var secondaryBodyWebViewCache: Dictionary<Int, UIWebView>!
    var secondaryBodyHeightCache: Dictionary<Int, CGFloat>!
    
    var posts: Array<Post>! {
        didSet {
            self.reloadTable()
        }
    }

    var loadingTop: Bool? {
        didSet {
            self.navigationController!.setIndeterminate(true)
            if let loadingTop = self.loadingTop {
                if loadingTop {
                    self.navigationController!.showProgress()
                } else {
                    self.navigationController!.cancelProgress()
                }
            }
        }
    }
    var loadingBottom: Bool?
    var loggingIn = false
    var lastPoint: CGPoint?
    
    required override init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.loadingTop = false
        self.loadingBottom = false
        
        self.bodyWebViewCache = Dictionary<Int, UIWebView>()
        self.bodyHeightCache = Dictionary<Int, CGFloat>()
        self.secondaryBodyWebViewCache = Dictionary<Int, UIWebView>()
        self.secondaryBodyHeightCache = Dictionary<Int, CGFloat>()
        
        self.tableView = UITableView()
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.allowsSelection = true
        self.tableView.separatorStyle = UITableViewCellSeparatorStyle.None
        self.tableView.sectionHeaderHeight = 50
        self.tableView.sectionFooterHeight = 50
        self.tableView.showsVerticalScrollIndicator = false
        self.tableView.showsHorizontalScrollIndicator = false

        self.tableView.registerClass(TitleTableViewCell.classForCoder(), forCellReuseIdentifier: titleTableViewCellIdentifier)
        self.tableView.registerClass(PhotosetRowTableViewCell.classForCoder(), forCellReuseIdentifier: photosetRowTableViewCellIdentifier)
        self.tableView.registerClass(ContentTableViewCell.classForCoder(), forCellReuseIdentifier: contentTableViewCellIdentifier)
        self.tableView.registerClass(PostQuestionTableViewCell.classForCoder(), forCellReuseIdentifier: postQuestionTableViewCellIdentifier)
        self.tableView.registerClass(PostLinkTableViewCell.classForCoder(), forCellReuseIdentifier: postLinkTableViewCellIdentifier)
        self.tableView.registerClass(PostDialogueEntryTableViewCell.classForCoder(), forCellReuseIdentifier: postDialogueEntryTableViewCellIdentifier)
        self.tableView.registerClass(PostHeaderView.classForCoder(), forHeaderFooterViewReuseIdentifier: postHeaderViewIdentifier)
        
        self.view.addSubview(self.tableView)
        
        layout(self.tableView, self.view) { tableView, view in
            tableView.edges == view.edges; return
        }
        
        self.longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: Selector("didLongPress:"))
        self.longPressGestureRecognizer.delegate = self
        self.longPressGestureRecognizer.minimumPressDuration = 0.3
        self.view.addGestureRecognizer(self.longPressGestureRecognizer)

        self.panGestureRecognizer = UIPanGestureRecognizer(target: self, action: Selector("didPan:"))
        self.panGestureRecognizer.delegate = self
        self.view.addGestureRecognizer(self.panGestureRecognizer)

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Rewind, target: self, action: Selector("navigate:event:"))
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if let posts = self.posts {
            if countElements(posts) > 0 {
                return
            }
        }

        self.loadTop()
    }
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func loadTop() {}
    
    func loadMore() {}

    func navigate(sender: UIBarButtonItem, event: UIEvent) {
        if let touches = event.allTouches() {
            if let touch = touches.anyObject() as? UITouch {
                if let navigationController = self.navigationController {
                    let viewController = QuickNavigateController()
                    
                    viewController.startingPoint = touch.locationInView(self.view)
                    viewController.modalPresentationStyle = UIModalPresentationStyle.OverFullScreen
                    viewController.modalTransitionStyle = UIModalTransitionStyle.CrossDissolve
                    viewController.view.bounds = navigationController.view.bounds

                    viewController.completion = { navigateOption in
                        if let option = navigateOption {
                            switch(option) {
                            case .Dashboard:
                                navigationController.setViewControllers([DashboardViewController()], animated: false)
                            case .Likes:
                                navigationController.setViewControllers([LikesViewController()], animated: false)
                            case .Settings:
                                navigationController.dismissViewControllerAnimated(true, completion: { () -> Void in
                                    let settingsViewController = SettingsViewController(style: UITableViewStyle.Grouped)
                                    let settingsNavigationViewController = UINavigationController(rootViewController: settingsViewController)
                                    navigationController.presentViewController(settingsNavigationViewController, animated: true, completion: nil)
                                })
                                return
                            }
                        }
                        navigationController.dismissViewControllerAnimated(true, completion: nil)
                    }
                    
                    navigationController.presentViewController(viewController, animated: true, completion: nil)
                }
            }
        }
    }

    func reblogBlogName() -> (String) {
        return ""
    }

    func reloadTable() {
        if let posts = self.posts {
            var webViewsFinishedLoading = true
            for post in posts {
                if let content = post.body() {
                    if let height = self.bodyHeightCache[post.id] {} else {
                        return
                    }
                } else if let content = post.secondaryBody() {
                    if let height = self.secondaryBodyHeightCache[post.id] {} else {
                        return
                    }
                }
            }
        }
        
        self.tableView.reloadData()
    }
    
    func didLongPress(sender: UILongPressGestureRecognizer) {
        if sender.state == UIGestureRecognizerState.Began {
            self.tableView.scrollEnabled = false
            let point = sender.locationInView(self.navigationController!.view)
            let tableViewPoint = sender.locationInView(self.tableView)
            if let indexPath = self.tableView.indexPathForRowAtPoint(tableViewPoint) {
                if let cell = self.tableView.cellForRowAtIndexPath(indexPath) {
                    let post = self.posts[indexPath.section]
                    let viewController = QuickReblogViewController()
                    
                    viewController.startingPoint = point
                    viewController.post = post
                    viewController.transitioningDelegate = self
                    viewController.modalPresentationStyle = UIModalPresentationStyle.Custom
                    
                    viewController.view.bounds = self.navigationController!.view.bounds
                    
                    self.navigationController!.view.addSubview(viewController.view)
                    
                    viewController.view.layoutIfNeeded()
                    viewController.viewDidAppear(false)
                    
                    self.reblogViewController = viewController
                }
            }
        } else if sender.state == UIGestureRecognizerState.Ended {
            self.tableView.scrollEnabled = true
            
            if let viewController = self.reblogViewController {
                let point = viewController.startingPoint
                let tableViewPoint = tableView.convertPoint(point, fromView: self.navigationController!.view)
                if let indexPath = self.tableView.indexPathForRowAtPoint(tableViewPoint) {
                    if let cell = self.tableView.cellForRowAtIndexPath(indexPath) {
                        let post = self.posts[indexPath.section]
                        
                        if let quickReblogAction = viewController.reblogAction() {
                            switch quickReblogAction {
                            case .Reblog(let reblogType):
                                let reblogViewController = TextReblogViewController()
                                
                                reblogViewController.reblogType = reblogType
                                reblogViewController.post = post
                                reblogViewController.blogName = self.reblogBlogName()
                                reblogViewController.bodyHeightCache = self.bodyHeightCache
                                reblogViewController.secondaryBodyHeightCache = self.secondaryBodyHeightCache
                                reblogViewController.modalPresentationStyle = UIModalPresentationStyle.OverFullScreen
                                
                                self.presentViewController(reblogViewController, animated: true, completion: nil)
                            case .Share:
                                let postItemProvider = PostItemProvider(placeholderItem: "")
                                
                                postItemProvider.post = post
                                
                                var activityItems: Array<UIActivityItemProvider> = [ postItemProvider ]
                                if let photosetCell = cell as? PhotosetRowTableViewCell {
                                    if let image = photosetCell.imageAtPoint(self.view.convertPoint(point, toView: photosetCell)) {
                                        let imageItemProvider = ImageItemProvider(placeholderItem: image)
                                        
                                        imageItemProvider.image = image
                                        
                                        activityItems.append(imageItemProvider)
                                    }
                                }
                                
                                let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
                                self.presentViewController(activityViewController, animated: true, completion: nil)
                            case .Like:
                                if post.liked.boolValue {
                                    TMAPIClient.sharedInstance().unlike("\(post.id)", reblogKey: post.reblogKey, callback: { (response, error) -> Void in
                                        if let e = error {
                                            println(e)
                                        } else {
                                            post.liked = false
                                        }
                                    })
                                } else {
                                    TMAPIClient.sharedInstance().like("\(post.id)", reblogKey: post.reblogKey, callback: { (response, error) -> Void in
                                        if let e = error {
                                            println(e)
                                        } else {
                                            post.liked = true
                                        }
                                    })
                                }
                            }
                        }
                    }
                }
                
                viewController.view.removeFromSuperview()
            }
            
            self.reblogViewController = nil
        }
    }
    
    func didPan(sender: UIPanGestureRecognizer) {
        if let viewController = self.reblogViewController {
            viewController.updateWithPoint(sender.locationInView(viewController.view))
        }
    }
    
    // MARK: UITableViewDataSource
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if let posts = self.posts {
            return posts.count
        }
        return 0
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let post = self.posts[section]
        switch post.type {
        case "photo":
            let postPhotos = post.photos()
            if postPhotos.count == 1 {
                return 2
            }
            return post.layoutRows().count + 1
        case "text":
            return 2
        case "answer":
            return 2
        case "quote":
            return 2
        case "link":
            return 2
        case "chat":
            return 1 + post.dialogueEntries().count
        case "video":
            return 2
        case "audio":
            return 2
        default:
            return 0
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let post = posts[indexPath.section]
        switch post.type {
        case "photo":
            if indexPath.row == self.tableView(tableView, numberOfRowsInSection: indexPath.section) - 1 {
                let cell = tableView.dequeueReusableCellWithIdentifier(contentTableViewCellIdentifier) as ContentTableViewCell!
                cell.content = post.htmlBodyWithWidth(tableView.frame.size.width)
                return cell
            }
            
            let cell = tableView.dequeueReusableCellWithIdentifier(photosetRowTableViewCellIdentifier) as PhotosetRowTableViewCell!
            let postPhotos = post.photos()
            if postPhotos.count == 1 {
                cell.images = postPhotos
            } else {
                let photosetLayoutRows = post.layoutRows()
                var photosIndexStart = 0
                for photosetLayoutRow in photosetLayoutRows[0..<indexPath.row] {
                    photosIndexStart += photosetLayoutRow
                }
                let photosetLayoutRow = photosetLayoutRows[indexPath.row]
                
                cell.images = Array(postPhotos[(photosIndexStart)..<(photosIndexStart + photosetLayoutRow)])
            }
            cell.contentWidth = tableView.frame.size.width
            
            return cell
        case "text":
            switch TextRow(rawValue: indexPath.row)! {
            case .Title:
                let cell = tableView.dequeueReusableCellWithIdentifier(titleTableViewCellIdentifier) as TitleTableViewCell!
                cell.titleLabel.text = post.title()
                return cell
            case .Body:
                let cell = tableView.dequeueReusableCellWithIdentifier(contentTableViewCellIdentifier) as ContentTableViewCell!
                cell.content = post.htmlBodyWithWidth(tableView.frame.size.width)
                return cell
            }
        case "answer":
            switch AnswerRow(rawValue: indexPath.row)! {
            case .Question:
                let cell = tableView.dequeueReusableCellWithIdentifier(postQuestionTableViewCellIdentifier) as PostQuestionTableViewCell!
                cell.post = post
                return cell
            case .Answer:
                let cell = tableView.dequeueReusableCellWithIdentifier(contentTableViewCellIdentifier) as ContentTableViewCell!
                cell.content = post.htmlBodyWithWidth(tableView.frame.size.width)
                return cell
            }
        case "quote":
            switch QuoteRow(rawValue: indexPath.row)! {
            case .Quote:
                let cell = tableView.dequeueReusableCellWithIdentifier(contentTableViewCellIdentifier) as ContentTableViewCell!
                cell.content = post.htmlBodyWithWidth(tableView.frame.size.width)
                return cell
            case .Source:
                let cell = tableView.dequeueReusableCellWithIdentifier(contentTableViewCellIdentifier) as ContentTableViewCell!
                cell.content = post.htmlSecondaryBodyWithWidth(tableView.frame.size.width)
                return cell
            }
        case "link":
            switch LinkRow(rawValue: indexPath.row)! {
            case .Link:
                let cell = tableView.dequeueReusableCellWithIdentifier(postLinkTableViewCellIdentifier) as PostLinkTableViewCell!
                cell.post = post
                return cell
            case .Description:
                let cell = tableView.dequeueReusableCellWithIdentifier(contentTableViewCellIdentifier) as ContentTableViewCell!
                cell.content = post.htmlBodyWithWidth(tableView.frame.size.width)
                return cell
            }
        case "chat":
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier(titleTableViewCellIdentifier) as TitleTableViewCell!
                cell.titleLabel.text = post.title()
                return cell;
            }
            let dialogueEntry = post.dialogueEntries()[indexPath.row - 1]
            let cell = tableView.dequeueReusableCellWithIdentifier(postDialogueEntryTableViewCellIdentifier) as PostDialogueEntryTableViewCell!
            cell.dialogueEntry = dialogueEntry
            return cell
        case "video":
            let cell = tableView.dequeueReusableCellWithIdentifier(contentTableViewCellIdentifier) as ContentTableViewCell!
            switch VideoRow(rawValue: indexPath.row)! {
            case .Player:
                cell.content = post.htmlSecondaryBodyWithWidth(tableView.frame.size.width)
            case .Caption:
                cell.content = post.htmlBodyWithWidth(tableView.frame.size.width)
            }
            return cell
        case "audio":
            let cell = tableView.dequeueReusableCellWithIdentifier(contentTableViewCellIdentifier) as ContentTableViewCell!
            switch AudioRow(rawValue: indexPath.row)! {
            case .Player:
                cell.content = post.htmlSecondaryBodyWithWidth(tableView.frame.size.width)
            case .Caption:
                cell.content = post.htmlBodyWithWidth(tableView.frame.size.width)
            }
            return cell
        default:
            return tableView.dequeueReusableCellWithIdentifier(contentTableViewCellIdentifier) as UITableViewCell!
        }
    }
    
    // MARK: UITableViewDelegate
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let post = posts[section]
        let view = tableView.dequeueReusableHeaderFooterViewWithIdentifier(postHeaderViewIdentifier) as PostHeaderView
        
        view.post = post
        
        return view
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let post = posts[indexPath.section]
        switch post.type {
        case "photo":
            if indexPath.row == self.tableView(tableView, numberOfRowsInSection: indexPath.section) - 1 {
                if let height = self.bodyHeightCache[post.id] {
                    return height
                }
                return 0
            }
            
            let postPhotos = post.photos()
            var images: Array<PostPhoto>!
            
            if postPhotos.count == 1 {
                images = postPhotos
            } else {
                let photosetLayoutRows = post.layoutRows()
                var photosIndexStart = 0
                for photosetLayoutRow in photosetLayoutRows[0..<indexPath.row] {
                    photosIndexStart += photosetLayoutRow
                }
                let photosetLayoutRow = photosetLayoutRows[indexPath.row]
                
                images = Array(postPhotos[(photosIndexStart)..<(photosIndexStart + photosetLayoutRow)])
            }
            
            let imageCount = images.count
            let imageWidth = tableView.frame.size.width / CGFloat(images.count)
            let minHeight = images.map { (image: PostPhoto) -> CGFloat in
                let scale = image.height() / image.width()
                return imageWidth * scale
                }.reduce(CGFloat.max, combine: { min($0, $1) })
            
            return minHeight
        case "text":
            switch TextRow(rawValue: indexPath.row)! {
            case .Title:
                if let title = post.title() {
                    return TitleTableViewCell.heightForTitle(title, width: tableView.frame.size.width)
                }
                return 0
            case .Body:
                if let height = self.bodyHeightCache[post.id] {
                    return height
                }
                return 0
            }
        case "answer":
            switch AnswerRow(rawValue: indexPath.row)! {
            case .Question:
                return PostQuestionTableViewCell.heightForPost(post, width: tableView.frame.size.width)
            case .Answer:
                if let height = self.bodyHeightCache[post.id] {
                    return height
                }
                return 0
            }
        case "quote":
            switch QuoteRow(rawValue: indexPath.row)! {
            case .Quote:
                if let height = self.bodyHeightCache[post.id] {
                    return height
                }
                return 0
            case .Source:
                if let height = self.secondaryBodyHeightCache[post.id] {
                    return height
                }
                return 0
            }
        case "link":
            switch LinkRow(rawValue: indexPath.row)! {
            case .Link:
                return PostLinkTableViewCell.heightForPost(post, width: tableView.frame.size.width)
            case .Description:
                if let height = self.bodyHeightCache[post.id] {
                    return height
                }
                return 0
            }
        case "chat":
            if indexPath.row == 0 {
                if let title = post.title() {
                    return TitleTableViewCell.heightForTitle(title, width: tableView.frame.size.width)
                }
                return 0
            }
            let dialogueEntry = post.dialogueEntries()[indexPath.row - 1]
            return PostDialogueEntryTableViewCell.heightForPostDialogueEntry(dialogueEntry, width: tableView.frame.size.width)
        case "video":
            switch VideoRow(rawValue: indexPath.row)! {
            case .Player:
                if let height = self.secondaryBodyHeightCache[post.id] {
                    return height
                }
                return 0
            case .Caption:
                if let height = self.bodyHeightCache[post.id] {
                    return height
                }
                return 0
            }
        case "video":
            switch AudioRow(rawValue: indexPath.row)! {
            case .Player:
                if let height = self.secondaryBodyHeightCache[post.id] {
                    return height
                }
                return 0
            case .Caption:
                if let height = self.bodyHeightCache[post.id] {
                    return height
                }
                return 0
            }
        default:
            return 0
        }
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let cell = tableView.cellForRowAtIndexPath(indexPath) {
            if let photosetRowCell = cell as? PhotosetRowTableViewCell {
                let post = self.posts[indexPath.section]
                let viewController = ImagesViewController()

                viewController.post = post

                self.presentViewController(viewController, animated: true, completion: nil)
            }
        }
    }

    func tableView(tableView: UITableView, didEndDisplayingCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if let cell = tableView.cellForRowAtIndexPath(indexPath) as? PhotosetRowTableViewCell {
            cell.cancelDownloads()
        }
    }
    
    // MARK: UIScrollViewDelegate
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        let distanceFromBottom = scrollView.contentSize.height - scrollView.frame.size.height - scrollView.contentOffset.y
        
        if distanceFromBottom < 2000 {
            self.loadMore()
        }
        
        if !self.loadingTop! {
            if let navigationController = self.navigationController {
                navigationController.setIndeterminate(false)
                if scrollView.contentOffset.y < 0 {
                    let distanceFromTop = scrollView.contentOffset.y + scrollView.contentInset.top + requiredRefreshDistance
                    let progress = 1 - max(min(distanceFromTop / requiredRefreshDistance, 1), 0)
                    navigationController.showProgress()
                    navigationController.setProgress(progress, animated: false)
                } else {
                    navigationController.cancelProgress()
                }
            }
        }
    }
    
    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let distanceFromTop = scrollView.contentOffset.y + scrollView.contentInset.top
        if -distanceFromTop > self.requiredRefreshDistance {
            self.loadTop()
        }
    }
    
    // MARK: UIWebViewDelegate
    
    func webViewDidFinishLoad(webView: UIWebView!) {
        if let postId = self.bodyWebViewCache.keyForObject(webView, isEqual: ==) {
            self.bodyHeightCache[postId] = webView.documentHeight()
            self.bodyWebViewCache[postId] = nil
            self.reloadTable()
        } else if let postId = self.secondaryBodyWebViewCache.keyForObject(webView, isEqual: ==) {
            self.secondaryBodyHeightCache[postId] = webView.documentHeight()
            self.secondaryBodyWebViewCache[postId] = nil
            self.reloadTable()
        }
    }
    
    // MARK: UIViewControllerTransitioningDelegate
    
    func animationControllerForPresentedController(presented: UIViewController, presentingController presenting: UIViewController, sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ReblogTransitionAnimator()
    }
    
    func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let animator = ReblogTransitionAnimator()
        
        animator.presenting = false
        
        return animator
    }
}

extension UIWebView {
    func documentHeight() -> (CGFloat) {
        return CGFloat(self.stringByEvaluatingJavaScriptFromString("var body = document.body, html = document.documentElement;Math.max( body.scrollHeight, body.offsetHeight,html.clientHeight, html.scrollHeight, html.offsetHeight );")!.toInt()!)
    }
}

extension Dictionary {
    func keyForObject(object: Value!, isEqual: (Value!, Value!) -> (Bool)) -> (Key?) {
        for key in self.keys {
            if isEqual(object, self[key] as Value!) {
                return key
            }
        }
        return nil
    }
}
