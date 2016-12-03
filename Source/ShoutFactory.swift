import UIKit

var shoutViews = [ShoutView]()

public class ShoutView: UIView {

  public struct Dimensions {
    public static let indicatorHeight: CGFloat = 6
    public static let indicatorWidth: CGFloat = 30
    public static let imageSize: CGFloat = 27
    public static let imageOffset: CGFloat = 12
    public static var height: CGFloat = UIApplication.shared.isStatusBarHidden ? 55 : 65
    public static var textOffset: CGFloat = 47
  }

  public private(set) lazy var backgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = ColorList.Shout.background
    view.alpha = 0.98
    view.clipsToBounds = true

    return view
    }()

  public private(set) lazy var gestureContainer: UIView = {
    let view = UIView()
    view.userInteractionEnabled = true

    return view
    }()

  public private(set) lazy var indicatorView: UIView = {
    let view = UIView()
    view.backgroundColor = ColorList.Shout.dragIndicator
    view.layer.cornerRadius = Dimensions.indicatorHeight / 2
    view.userInteractionEnabled = true

    return view
    }()

  public private(set) lazy var imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.layer.cornerRadius = Dimensions.imageSize / 2
    imageView.clipsToBounds = true
    imageView.contentMode = .ScaleAspectFill

    return imageView
    }()

  public private(set) lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.font = FontList.Shout.title
    label.textColor = ColorList.Shout.title
    label.numberOfLines = 2

    return label
    }()

  public private(set) lazy var subtitleLabel: UILabel = {
    let label = UILabel()
    label.font = FontList.Shout.subtitle
    label.textColor = ColorList.Shout.subtitle
    label.numberOfLines = 2

    return label
    }()

  public private(set) lazy var tapGestureRecognizer: UITapGestureRecognizer = { [unowned self] in
    let gesture = UITapGestureRecognizer()
    gesture.addTarget(self, action: #selector(ShoutView.handleTapGestureRecognizer))

    return gesture
    }()

  public private(set) lazy var panGestureRecognizer: UIPanGestureRecognizer = { [unowned self] in
    let gesture = UIPanGestureRecognizer()
    gesture.addTarget(self, action: #selector(ShoutView.handlePanGestureRecognizer))

    return gesture
    }()

  public private(set) var announcement: Announcement?
  public private(set) var displayTimer = NSTimer()
  public private(set) var panGestureActive = false
  public private(set) var shouldSilent = false
  public private(set) var completion: (() -> ())?

  // MARK: - Initializers

  public override init(frame: CGRect) {
    super.init(frame: frame)

    addSubview(backgroundView)
    [indicatorView, imageView, titleLabel, subtitleLabel, gestureContainer].forEach {
      backgroundView.addSubview($0) }

    clipsToBounds = false
    userInteractionEnabled = true
    layer.shadowColor = UIColor.blackColor().CGColor
    layer.shadowOffset = CGSize(width: 0, height: 0.5)
    layer.shadowOpacity = 0.1
    layer.shadowRadius = 0.5

    addGestureRecognizer(tapGestureRecognizer)
    gestureContainer.addGestureRecognizer(panGestureRecognizer)

    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ShoutView.orientationDidChange), name: UIDeviceOrientationDidChangeNotification, object: nil)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
  }

  // MARK: - Configuration

  public func craft(announcement: Announcement, to: UIViewController, completion: (() -> ())?) {
    Dimensions.height = UIApplication.sharedApplication().statusBarHidden ? 70 : 80

    panGestureActive = false
    shouldSilent = false
    configureView(announcement)
    shout(to: to)

    self.completion = completion
  }

  public func configureView(announcement: Announcement) {
    self.announcement = announcement
    imageView.image = announcement.image
    titleLabel.text = announcement.title
    titleLabel.font = announcement.titleFont
    subtitleLabel.text = announcement.subtitle

    displayTimer.invalidate()
    displayTimer = NSTimer.scheduledTimerWithTimeInterval(announcement.duration,
      target: self, selector: #selector(ShoutView.displayTimerDidFire), userInfo: nil, repeats: false)

    setupFrames()
  }

  public func shout(to controller: UIViewController) {
    let width = UIScreen.main.bounds.width
    controller.view.addSubview(self)
    
    frame = CGRect(x: 0, y: shoutViews.last?.frame.maxY ?? 0, width: width, height: 0)
    backgroundView.frame = CGRect(x: 0, y: 0, width: width, height: 0)
    
    UIView.animate(withDuration: 0.35, animations: {
        self.frame.size.height = Dimensions.height
        self.backgroundView.frame.size.height = self.frame.height
    })
  }

  // MARK: - Setup

  public func setupFrames() {
    let totalWidth = UIScreen.main.bounds.width
    let offset: CGFloat = UIApplication.shared.isStatusBarHidden || shoutViews.count > 0 ? 2.5 : 5
    let textOffsetX: CGFloat = imageView.image != nil ? Dimensions.textOffset : 18
    let imageSize: CGFloat = imageView.image != nil ? Dimensions.imageSize : 0
    
    [titleLabel, subtitleLabel].forEach {
        $0.frame.size.width = totalWidth - imageSize - (Dimensions.imageOffset * 2)
        $0.sizeToFit()
    }
    
    Dimensions.height += subtitleLabel.frame.height
    
    backgroundView.frame.size = CGSize(width: totalWidth, height: Dimensions.height)
    gestureContainer.frame = backgroundView.frame
    indicatorView.frame = CGRect(x: (totalWidth - Dimensions.indicatorWidth) / 2,
                                 y: Dimensions.height - Dimensions.indicatorHeight - 5, width: Dimensions.indicatorWidth, height: Dimensions.indicatorHeight)
    
    imageView.frame = CGRect(x: Dimensions.imageOffset, y: (Dimensions.height - imageSize) / 2 + offset,
                             width: imageSize, height: imageSize)
    
    let textOffsetY = imageView.image != nil ? imageView.frame.origin.x + 3 : textOffsetX + 5
    
    titleLabel.frame.origin = CGPoint(x: textOffsetX, y: textOffsetY)
    subtitleLabel.frame.origin = CGPoint(x: textOffsetX, y: titleLabel.frame.maxY + 2.5)
    
    if subtitleLabel.text?.isEmpty ?? true {
        titleLabel.center.y = imageView.center.y
    }
  }

  // MARK: - Actions

  public func silent() {
    func getSelfIndex() -> Int {
        var selfIndex = 0
        for (index, v) in shoutViews.enumerated() {
            if v == self {
                selfIndex = index
            }
        }
        
        return selfIndex
    }
    
    UIView.animate(withDuration: 0.35, animations: {
        for (index, v) in shoutViews.enumerated() {
            if index > getSelfIndex() {
                v.frame.origin.y -= self.frame.size.height
            }
        }
        self.frame.size.height = 0
        self.backgroundView.frame.size.height = self.frame.height
    }, completion: { finished in
        self.completion?()
        self.displayTimer.invalidate()
        self.removeFromSuperview()
        shoutViews.remove(at: getSelfIndex())
    })
  }

  // MARK: - Timer methods

  public func displayTimerDidFire() {
    shouldSilent = true

    if panGestureActive { return }
    silent()
  }

  // MARK: - Gesture methods

  @objc private func handleTapGestureRecognizer() {
    guard let announcement = announcement else { return }
    announcement.action?()
    silent()
  }

  @objc private func handlePanGestureRecognizer() {
    let translation = panGestureRecognizer.translationInView(self)
    var duration: NSTimeInterval = 0

    if panGestureRecognizer.state == .Changed || panGestureRecognizer.state == .Began {
      panGestureActive = true
      if translation.y >= 12 {
        frame.size.height = Dimensions.height + 12 + (translation.y) / 25
      } else {
        frame.size.height = Dimensions.height + translation.y
      }
    } else {
      panGestureActive = false
      let height = translation.y < -5 || shouldSilent ? 0 : Dimensions.height

      duration = 0.2
      UIView.animateWithDuration(duration, animations: {
        self.frame.size.height = height
        }, completion: { _ in if translation.y < -5 { self.completion?(); self.removeFromSuperview() }})
    }

    UIView.animateWithDuration(duration, animations: {
      self.backgroundView.frame.size.height = self.frame.height
      self.gestureContainer.frame.origin.y = self.frame.height - 20
      self.indicatorView.frame.origin.y = self.frame.height - Dimensions.indicatorHeight - 5
    })
  }


  // MARK: - Handling screen orientation

  func orientationDidChange() {
    setupFrames()
  }
}
