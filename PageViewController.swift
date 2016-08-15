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
//
//  PageViewController.swift

import UIKit

@objc
protocol PageViewControllerDelegate {

	@objc optional func pageViewController(_ pageViewController: PageViewController, presentedViewController: UIViewController?)
	@objc optional func pageViewController(_ pageViewController: PageViewController, createdViewController: UIViewController?)
}

@objc
protocol PageViewControllerDataSource {

	@objc optional func pageViewController(_ pageViewController: PageViewController, viewControllerForIndex: Int) -> UIViewController?
	@objc optional func pageViewControllerPageCount(_ pageViewController: PageViewController) -> Int
}

@objc
protocol PageViewControllerClient {

	@objc optional func pageViewControllerActivated(_ pageViewController: PageViewController, previouslyActiveViewController: UIViewController?)
	@objc optional func pageViewControllerDeactived(_ pageViewController: PageViewController, activeViewController: UIViewController?)
}

@objc
class PageViewController: UIViewController {

	//the paging direction - default = .horizontal
	enum Direction { case horizontal, vertical }
	var direction: Direction = .horizontal {
		didSet {
			rectClass = (direction == .horizontal) ? HorizontalAgnosticRect.self : VerticalAgnoticRect.self
			scrollView.alwaysBounceVertical = direction == .vertical
			scrollView.alwaysBounceHorizontal = direction == .horizontal
		}
	}
	weak var delegate: PageViewControllerDelegate? = nil
	weak var dataSource: PageViewControllerDataSource? = nil

	weak var currentViewController: UIViewController? {
		return viewControllersByPage[currentPage]
	}
	//you can either:
	//implement a dataSource and provide new viewcontrollers when prompted or
	//specify an array of viewcontroller classes from which PageViewController
	//will create each page using the provided classes
	var viewControllerClasses: [UIViewController.Type]? = nil
	//if you implement a datasource you may either:
	//1) implement pageViewControllerPageCount to specify the page count
	//   or return nil in viewControllerForIndex when the last page is request
	//or
	//2) specify a pageCount
	var pageCount: Int {
		get {
			var pageCount = 0
			if let count = viewControllerClasses?.count {
				pageCount = count
			}
			if let count = presetPageCount {
				pageCount = count
			}
			if let count = self.dataSource?.pageViewControllerPageCount?(self) {
				pageCount = count
			}
			return pageCount
		}
		set {
			presetPageCount = newValue
			if scrollView.contentSize == .zero {
				setContentSize(newValue)
			}
		}
	}
	func goto(page: Int) {
		assert(scrollView.superview! == view)
		DispatchQueue.main.async {
			if let vc = self.viewController(index: page) {
				self.setContentSize(self.pageCount)
				self.attachViewController(viewController: vc, page: page)
				self.currentPage = page
				self.scrollView.scrollRectToVisible(self.frameForPage(page), animated: false)
			}
		}
	}

	enum Traversal { case next, prev }
	func goto(traversal: Traversal) {
		goto(page: currentPage + (traversal == .next ? 1 : -1))
	}

	private var presetPageCount: Int? = nil
	private func viewController(index: Int) -> UIViewController? {
		if let requestedClass = viewControllerClasses?[index] {
			let vc = requestedClass.init()
			delegate?.pageViewController?(self, createdViewController: vc)
			return vc
		}
		if let count = presetPageCount, index >= count {
			return nil
		}
		if let count = dataSource?.pageViewControllerPageCount?(self), index >= count {
			return nil
		}
		return self.dataSource?.pageViewController?(self, viewControllerForIndex: index)
	}

	private var viewControllersByPage: [Int : UIViewController] = [:]

	private let containerViews: [UIView] =  [UIView(), UIView()]
	private var rectClass: AgnosticRect.Type = HorizontalAgnosticRect.self
	private var previousPage = -1
	private(set) var currentPage = -1 {
		willSet {
			previousPage = currentPage
		}
		didSet {
		}
	}
	private(set) lazy var scrollView: UIScrollView = {
		let scrollView = UIScrollView()
		scrollView.scrollsToTop = false
		scrollView.showsVerticalScrollIndicator = false
		scrollView.showsHorizontalScrollIndicator = false
		scrollView.isPagingEnabled = true
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.alwaysBounceVertical = self.direction == .vertical
		scrollView.alwaysBounceHorizontal = self.direction == .horizontal
		scrollView.isDirectionalLockEnabled = true
		return scrollView
	}()

	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nil, bundle: nil)
		for view in containerViews {
			view.frame = rectClass.offscreen
		}
	}
	deinit {
		scrollView.removeObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: UIScrollView.bounds)))
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

extension PageViewController {//MARK: view lifecycle

	override func loadView() {
		view = UIView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(scrollView)
		for container in containerViews {
			container.translatesAutoresizingMaskIntoConstraints = false
			scrollView.addSubview(container)
		}
		DispatchQueue.main.async {
			self.scrollView.addObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: UIScrollView.bounds)), options: .new, context: nil)
		}
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		scrollView.frame = CGRect(origin: .zero, size: view.frame.size)
		for current in containerViews {
			current.frame = CGRect(origin: current.frame.origin, size: view.frame.size)
		}
	}

	private func setContentSize(_ pageCount: Int) {
		let frame = rectClass.init(view.frame)
		frame.size.relevant = frame.size.relevant * CGFloat(pageCount)
		scrollView.contentSize = frame.rect.size
	}
}

extension PageViewController {//MARK: frame calculation

	private func pageForFrame(_ frame: CGRect) -> CGFloat {
		let rect = rectClass.init(frame)
		return rect.size.relevant == 0 ? -9999999 : rect.origin.relevant / rect.size.relevant
	}

	private func frameForPage(_ page: Int) -> CGRect {
		let frame = rectClass.init(scrollView.bounds)
		frame.origin.relevant = frame.size.relevant * CGFloat(page)
		return frame.rect
	}
}

extension PageViewController {//MARK: scroll management

	override func observeValue(forKeyPath keyPath: String?, of object: AnyObject?, change: [NSKeyValueChangeKey : AnyObject]?, context: UnsafeMutablePointer<Void>?) {
		guard object === scrollView else {
			return
		}
		let pageNumber = newlyPresentedPageNumber()
		if pageNumber != nil {
			currentPage = pageNumber!
		}
		trimOffscreenViews()
		trimViewControllers()
		attachIncomingViews()
		if pageNumber != nil {
			delegateViewControllerPresentationMessages()
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
				viewController.didMove(toParentViewController: self)
			}
		}
	}

	private func detachViewController(_ viewController: UIViewController) {

		if let view = viewController.view {
			view.superview?.frame = rectClass.offscreen
			viewController.willMove(toParentViewController: nil)
			view.removeFromSuperview()
			viewController.removeFromParentViewController()
		}
	}

	private func attachView(_ childView: UIView, offscreen: UIView? = nil) -> UIView? {

		guard let container = offscreen ?? offscreenView() else {
			return nil
		}
		container.addSubview(childView)
		childView.frame = CGRect(origin: .zero, size: container.frame.size)
		return container
	}

	private func delegateViewControllerPresentationMessages() {

		let viewController = viewControllersByPage[currentPage]
		delegate?.pageViewController?(self, presentedViewController: viewController)
		if let client = viewController as? PageViewControllerClient {
			client.pageViewControllerActivated?(self, previouslyActiveViewController: viewControllersByPage[previousPage])
		}
		if let previous = viewControllersByPage[previousPage] as? PageViewControllerClient {
			previous.pageViewControllerDeactived?(self, activeViewController: viewController)
		}
	}

	private func offscreenView() -> UIView? {
		for current in containerViews {
			if !current.frame.intersects(scrollView.bounds) {
				return current
			}
		}
		return nil
	}

	private func newlyPresentedPageNumber() -> Int? {
		let page = Int(pageForFrame(scrollView.bounds))
		print(page)
		if page != currentPage {
			return page
		}
		return nil
	}

	private func visiblePages() -> Set<Int> {
		let rect = rectClass.init(scrollView.bounds)
		rect.origin.relevant += rect.size.relevant - 1
		return [Int(pageForFrame(scrollView.bounds)), Int(pageForFrame(rect.rect))]
	}
	
	private func containerPages() -> Set<Int> {
		return [Int(pageForFrame(containerViews[0].frame)), Int(pageForFrame(containerViews[1].frame))]
	}

	private func newlyVisiblePage() -> Int? {
		
		var v = visiblePages()
		v.subtract(containerPages())
		return v.first
	}

	private func attachIncomingViews() {

		guard let nextPage = newlyVisiblePage() else {
			return
		}
		if let existingViewController = viewControllersByPage[nextPage] {
			if existingViewController.view.superview == nil {
				if let container = attachView(existingViewController.view) {
					container.frame = frameForPage(nextPage)
				}
			}
		} else {
			if let vc = self.viewController(index: nextPage) {
				attachViewController(viewController: vc, page: nextPage)				
			}
		}
	}

	private func trimOffscreenViews() {

		if let view = offscreenView() {
			if view.subviews.count > 0 {
				view.subviews[0].removeFromSuperview()
				view.frame = rectClass.offscreen
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
			viewControllersByPage.removeValue(forKey: page)
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
	static var offscreen: CGRect { get }
	init(_ frame: CGRect)
	init(_ size: CGSize)
	init(_ rect: AgnosticRect)
}

extension PageViewController {

	private class HorizontalAgnosticRect: AgnosticRect {
		static var offscreen: CGRect {
			return CGRect(x: -999999, y: 0, width: 1, height: 1)
		}
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
		static var offscreen: CGRect {
			return CGRect(x: 0, y: -9999999, width: 1, height: 1)
		}
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
