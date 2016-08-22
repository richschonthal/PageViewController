/*
Copyright 2016 Rich Schonthal

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import UIKit

@objc
protocol PageViewControllerDelegate {

	@objc optional func pageViewController(pageViewController: PageViewController, presentedViewController: UIViewController?, index: Int)
	@objc optional func pageViewController(pageViewController: PageViewController, createdViewController: UIViewController?)
}

@objc
protocol PageViewControllerDataSource {

	@objc optional func pageViewController(pageViewController: PageViewController, viewControllerForIndex: Int) -> UIViewController?
	@objc optional func pageViewControllerPageCount(pageViewController: PageViewController) -> Int
}

@objc
protocol PageViewControllerClient {

	@objc optional func pageViewControllerActivated(pageViewController: PageViewController, previouslyActiveViewController: UIViewController?)
	@objc optional func pageViewControllerDeactived(pageViewController: PageViewController, activeViewController: UIViewController?)
}

@objc
class PageViewController: UIViewController {

	//the paging direction - default = .horizontal
	//	enum Direction { case horizontal, vertical }
	//	var direction: Direction = .horizontal {
	//		didSet {
	//			rectClass = (direction == .horizontal) ? HorizontalAgnosticRect.self : VerticalAgnoticRect.self
	//			scrollView.alwaysBounceVertical = direction == .vertical
	//			scrollView.alwaysBounceHorizontal = direction == .horizontal
	//		}
	//	}
	weak var delegate: PageViewControllerDelegate? = nil
	weak var dataSource: PageViewControllerDataSource? = nil

	weak var currentViewController: UIViewController? {
		return viewControllersByPage[currentPage]
	}
	//to specify your number of viewcontrollers you may either:
	//1) implement pageViewControllerPageCount to specify the page count
	//or
	//2) specify a pageCount
	var pageCount: Int {
		get {
			if let count = presetPageCount {
				return count
			}
			if let count = self.dataSource?.pageViewControllerPageCount?(self) {
				return count
			}
			return 0
		}
		set {
			presetPageCount = newValue
			if scrollView.contentSize == .zero {
				setContentSize(newValue)
			}
		}
	}

	func reset() {
		previousPage = -1
		currentPage = 0
		presetPageCount = nil
		viewControllersByPage.removeAll()
		for current in containerViews {
			if current.subviews.count > 0 {
				current.subviews[0].removeFromSuperview()
				current.hidden = true
			}
		}
	}

	private let queue: NSOperationQueue = {
		let q = NSOperationQueue()
		q.underlyingQueue = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL)
		return q
	}()
	private var deiniting = false

	func gotoPage(page: Int, animated: Bool) {
		assert(scrollView.superview! == view)
		queue.addOperationWithBlock { [weak self] in
			guard let me = self else {
				return
			}
			if me.deiniting {
				return
			}
			dispatch_async(dispatch_get_main_queue(), {
				me.setContentSize(me.pageCount)
				me.currentPage = page
				me.scrollView.scrollRectToVisible(me.frameForPage(page), animated: animated)
				me.attachIncomingViews()
				me.delegateViewControllerPresentationMessages()
			})
		}
	}

	func gotoPage(page: Int) {
		gotoPage(page, animated: false)
	}

	enum Traversal { case next, prev }
	func gotoPage(traversal: Traversal) {
		gotoPage(currentPage + (traversal == .next ? 1 : -1))
	}

	private var presetPageCount: Int? = nil
	private func viewControllerForIndex(index: Int) -> UIViewController? {

		if let count = presetPageCount where index >= count {
			return nil
		}
		if let count = dataSource?.pageViewControllerPageCount?(self) where index >= count {
			return nil
		}
		return self.dataSource?.pageViewController?(self, viewControllerForIndex: index)
	}

	private var viewControllersByPage: [Int : UIViewController] = [:]

	private let containerViews: [UIView] = {
		let containerViews = [PageContainerView(), PageContainerView()]
		for view in containerViews {
			view.hidden = true
		}
		return containerViews
	}()
	//	private var rectClass: AgnosticRect.Type = HorizontalAgnosticRect.self
	private var previousPage = -1
	private(set) var currentPage = -1 {
		willSet {
			previousPage = currentPage
		}
	}
	private(set) lazy var scrollView: UIScrollView = {

		let scrollView = UIScrollView()
		scrollView.scrollsToTop = false
		scrollView.showsVerticalScrollIndicator = false
		scrollView.showsHorizontalScrollIndicator = false
		scrollView.pagingEnabled = true
		scrollView.translatesAutoresizingMaskIntoConstraints = true
		//		scrollView.alwaysBounceVertical = self.direction == .vertical
		//		scrollView.alwaysBounceHorizontal = self.direction == .horizontal
		scrollView.alwaysBounceVertical = false
		scrollView.alwaysBounceHorizontal = true
		scrollView.directionalLockEnabled = true
		scrollView.frame = CGRect(origin: .zero, size: self.view.frame.size)
		scrollView.addObserver(self, forKeyPath: "bounds", options: .New, context: nil)
		return scrollView
	}()

	deinit {
		scrollView.removeObserver(self, forKeyPath: "bounds")
		self.deiniting = true
		self.queue.cancelAllOperations()
	}
}

extension PageViewController {//MARK: view lifecycle

	class PageView: UIView { }
	class PageContainerView: UIView { }

	override func loadView() {
		view = PageView()
		view.autoresizesSubviews = false
		view.translatesAutoresizingMaskIntoConstraints = true
		view.addSubview(scrollView)
		for container in containerViews {
			container.translatesAutoresizingMaskIntoConstraints = true
			scrollView.addSubview(container)
		}
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		let frame = HorizontalAgnosticRect.init(CGRect(origin: .zero, size: view.frame.size))
		scrollView.frame = frame.rect
		for current in containerViews {
			current.frame = CGRect(origin: current.frame.origin, size: view.frame.size)
		}
		self.queue.suspended = frame.size.relevant == 0
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		self.manageViews()
	}

	private func setContentSize(pageCount: Int) {
		let frame = HorizontalAgnosticRect(view.frame)
		frame.size.relevant = frame.size.relevant * CGFloat(pageCount)
		scrollView.contentSize = frame.rect.size
	}
}

extension PageViewController {//MARK: frame calculation

	private func pageForFrame(frame: CGRect) -> CGFloat {

		let rect = HorizontalAgnosticRect(frame)
		return rect.size.relevant == 0 ? -1 : rect.origin.relevant / rect.size.relevant
	}

	private func frameForPage(page: Int) -> CGRect {

		let frame = HorizontalAgnosticRect(scrollView.bounds)
		frame.origin.relevant = frame.size.relevant * CGFloat(page)
		return frame.rect
	}
}

extension PageViewController {//MARK: scroll management

	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {

		guard object === scrollView else {
			return
		}
		dispatch_async(dispatch_get_main_queue()) {
			self.manageViews()
		}
	}

	private func manageViews() {
		let pageNumber = self.newlyPresentedPageNumber()
		if pageNumber != nil {
			self.currentPage = pageNumber!
		}
		self.trimOffscreenViews()
		self.attachIncomingViews()
		self.trimViewControllers()
		if pageNumber != nil {
			self.delegateViewControllerPresentationMessages()
		}
	}

	private func attachViewController(viewController: UIViewController, page: Int) {

		if viewControllersByPage[page] === viewController && containerViews.contains(viewController.view!.superview!) {
			return
		}
		if let previouslyUsedViewController = viewControllersByPage[page], let container = attachView(previouslyUsedViewController.view) {
			container.frame = frameForPage(page)
		} else {
			viewControllersByPage[page] = viewController
			if let container = attachView(viewController.view) {
				addChildViewController(viewController)
				container.frame = frameForPage(page)
				viewController.didMoveToParentViewController(self)
			}
		}
	}

	private func detachViewController(viewController: UIViewController) {

		if let view = viewController.view {
			view.superview?.hidden = true
			viewController.willMoveToParentViewController(nil)
			view.removeFromSuperview()
			viewController.removeFromParentViewController()
		}
	}

	private func attachView(childView: UIView) -> UIView? {

		guard let container = offscreenView() else {
			return nil
		}
		container.addSubview(childView)
		container.hidden = false
		childView.frame = CGRect(origin: .zero, size: container.frame.size)
		return container
	}

	private func delegateViewControllerPresentationMessages() {

		guard let viewController = viewControllersByPage[currentPage] else {
			return
		}
		dispatch_async(dispatch_get_main_queue()) {
			let previouslyActiveViewController = self.viewControllersByPage[self.previousPage]
			self.delegate?.pageViewController?(self, presentedViewController: viewController, index: self.currentPage)
			(viewController as? PageViewControllerClient)?.pageViewControllerActivated?(self, previouslyActiveViewController:previouslyActiveViewController)
			(previouslyActiveViewController as? PageViewControllerClient)?.pageViewControllerDeactived?(self, activeViewController: viewController)
		}
	}

	private func offscreenView() -> UIView? {
		for current in containerViews {
			if current.hidden {
				return current
			}
		}
		return nil
	}

	private func newlyPresentedPageNumber() -> Int? {
		let page = Int(pageForFrame(scrollView.bounds))
		if page != currentPage {
			return page
		}
		return nil
	}

	private func visiblePages() -> Set<Int> {
		let rect = HorizontalAgnosticRect(scrollView.bounds)
		rect.origin.relevant += rect.size.relevant - 1
		return [Int(pageForFrame(scrollView.bounds)), Int(pageForFrame(rect.rect))]
	}

	private func containerPages() -> Set<Int> {
		return [containerViews[0].hidden ? -1 : Int(pageForFrame(containerViews[0].frame)), containerViews[1].hidden ? -2 : Int(pageForFrame(containerViews[1].frame))]
	}

	private func newlyVisiblePage() -> Int? {

		return visiblePages()
			.subtract(containerPages())
			.first
	}

	private func attachIncomingViews() {

		guard let nextPage = newlyVisiblePage() else {
			return
		}
		if let existingViewController = viewControllersByPage[nextPage] {
			if existingViewController.view.superview == nil {
				if let container = attachView(existingViewController.view) {
					container.frame = frameForPage(nextPage)
					container.hidden = false
				}
			}
		} else {
			if let vc = self.viewControllerForIndex(nextPage) {
				attachViewController(vc, page: nextPage)
			}
		}
	}

	private func trimOffscreenViews() {

		for current in containerViews {
			if !current.frame.intersects(scrollView.bounds) {
				if current.subviews.count > 0 {
					current.subviews[0].removeFromSuperview()
				}
				current.hidden = true
			}
		}
	}

	private func trimViewControllers() {

		var remove: [Int] = []
		for (page, viewController) in viewControllersByPage {
			switch page {
			case currentPage, currentPage - 1, currentPage + 1:
				break
			default:
				detachViewController(viewController)
				remove.append(page)
			}
		}
		for page in remove {
			viewControllersByPage.removeValueForKey(page)
		}
	}
}

private class AgnosticDuple {

	var relevant, other: CGFloat
	init(relevant: CGFloat, other: CGFloat) {
		self.relevant = relevant
		self.other = other
	}
}

private protocol AgnosticRect: CustomStringConvertible {

	var origin: AgnosticDuple { get }
	var size: AgnosticDuple { get }
	var rect: CGRect { get }
	init(_ frame: CGRect)
	init(_ size: CGSize)
	init(_ rect: AgnosticRect)
}

extension PageViewController {

	private class HorizontalAgnosticRect: AgnosticRect {

		var description: String {
			return String(rect)
		}
		let origin: AgnosticDuple
		let size: AgnosticDuple
		var rect: CGRect {
			return CGRect(x: origin.relevant, y: origin.other, width: size.relevant, height: size.other)
		}
		required init(_ frame: CGRect) {
			origin = AgnosticDuple(relevant: frame.origin.x, other: frame.origin.y)
			size = AgnosticDuple(relevant: frame.size.width, other: frame.size.height)
		}
		required init(_ size: CGSize) {
			origin = AgnosticDuple(relevant: 0, other: 0)
			self.size = AgnosticDuple(relevant: size.width, other: size.height)
		}
		required init(_ rect: AgnosticRect) {
			origin = AgnosticDuple(relevant: rect.origin.relevant, other: rect.origin.relevant)
			size = AgnosticDuple(relevant: rect.size.relevant, other: rect.size.relevant)
		}
	}
	private class VerticalAgnoticRect: AgnosticRect {

		var description: String {
			return String(rect)
		}
		let origin: AgnosticDuple
		let size: AgnosticDuple
		var rect: CGRect {
			return CGRect(x: origin.other, y: origin.relevant, width: size.other, height: size.relevant)
		}
		required init(_ frame: CGRect) {
			origin = AgnosticDuple(relevant: frame.origin.y, other: frame.origin.x)
			size = AgnosticDuple(relevant: frame.size.height, other: frame.size.width)
		}
		required init(_ size: CGSize) {
			origin = AgnosticDuple(relevant: 0, other: 0)
			self.size = AgnosticDuple(relevant: size.height, other: size.width)
		}
		required init(_ rect: AgnosticRect) {
			origin = AgnosticDuple(relevant: rect.origin.relevant, other: rect.origin.relevant)
			size = AgnosticDuple(relevant: rect.size.relevant, other: rect.size.relevant)
		}
	}
}
