import UIKit
import SwiftUI
import Foundation
import CoreMedia

class MediaControlsController: UIViewController {
    var sliderGrabbed = false
    
    var timeListened = 0.0
    var lastTimeUpdate = 0.0
    var targetListenTime = 9999999.0
    var listenedToCurrentSong = false
    
    // Kind of hacky. But the events we get when we change songs can be triggered in a weird way that makes
    // the slider kind of jump around, because the song changes, but the time that we are given by the media
    // controls hasn't yet changed back to 0. So do a little extra bookkeeping to keep this from happening
    var playingTrackId: Int64? = nil
    
    lazy var repeatIcon: UIImageView = {
        let icon = createIcon("repeat", weight: .bold)
        icon.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(toggleRepeat(tapGestureRecognizer:))
        ))
        return icon
    }()
    
    var backIcon: UIImageView {
        let icon = createIcon("backward.end.fill")
        icon.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(playPrevious(tapGestureRecognizer:))
        ))
        return icon
    }
    
    lazy var playIcon: UIImageView = {
        let icon = createIcon("play.fill", scale: .large)
        icon.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(playMusic(tapGestureRecognizer:))
        ))
        return icon
    }()
    
    lazy var pauseIcon: UIImageView = {
        let icon = createIcon("pause.fill", scale: .large)
        icon.isHidden = true
        icon.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(pauseMusic(tapGestureRecognizer:))
        ))
        return icon
    }()
    
    var forwardIcon: UIImageView {
        let icon = createIcon("forward.end.fill")
        icon.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(playNext(tapGestureRecognizer:))
        ))
        return icon
    }
    
    lazy var shuffleIcon: UIImageView = {
        let icon = createIcon("shuffle", weight: .bold)
        icon.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(toggleShuffle(tapGestureRecognizer:))
        ))
        return icon
    }()
    
    var songText: UILabel = {
        let label = UILabel()
        
        label.text = " " // Empty space just to take up vertical height
        label.textColor = .white
        label.font = label.font.withSize(12)
        
        return label
    }()
    
    var currentTime: UILabel = {
        let label = UILabel()
        
        label.textColor = .white
        label.text = "0:00"
        label.font = label.font.withSize(12)
        
        return label
    }()
    
    var totalTime: UILabel = {
        let label = UILabel()
        
        label.textColor = .white
        label.text = "0:00"
        label.font = label.font.withSize(12)
        
        return label
    }()
    
    lazy var slider: UISlider = {
        let slider = UISlider()
        slider.maximumValue = 1
        slider.minimumValue = 0
        slider.setValue(0, animated: false)
    
        slider.minimumTrackTintColor = Colors.lightBlue
        slider.maximumTrackTintColor = Colors.nearBlack
        slider.thumbTintColor = Colors.lightBlue

        let config = UIImage.SymbolConfiguration(scale: .small)
        let newImage = UIImage(systemName: "circle.fill", withConfiguration: config)?.tinted(color: Colors.lightBlue)

        slider.setThumbImage(newImage, for: .normal)
        slider.setThumbImage(newImage, for: .highlighted)

        slider.addTarget(self, action: #selector(self.handleSliderGrab), for: .touchDown)
        slider.addTarget(self, action: #selector(self.handleSliderRelease), for: .touchUpInside)
        slider.addTarget(self, action: #selector(self.handleSliderRelease), for: .touchUpOutside)
        slider.addTarget(self, action: #selector(self.handleSeek), for: .valueChanged)
        
        return slider
    }()
    
    override func viewDidLoad() {
        let content = UIStackView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.alignment = .center
        
        let topButtons = createTopButtons()
        let songTextView = createSongText()
        let bottomElements = createBottomElements()

        content.addArrangedSubview(topButtons)
        content.addArrangedSubview(songTextView)
        content.addArrangedSubview(bottomElements)
        
        content.setCustomSpacing(8.0, after: topButtons)
        content.setCustomSpacing(8.0, after: songTextView)
        
        self.view.addSubview(content)
        self.view.backgroundColor = Colors.primary
        self.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            self.view.heightAnchor.constraint(equalToConstant: 90.0),
            
            content.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 10),
            content.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            content.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            
            topButtons.leftAnchor.constraint(equalTo: content.leftAnchor, constant: 10),
            topButtons.rightAnchor.constraint(equalTo: content.rightAnchor, constant: -10),
            
            bottomElements.leftAnchor.constraint(equalTo: content.leftAnchor, constant: 10),
            bottomElements.rightAnchor.constraint(equalTo: content.rightAnchor, constant: -10)
        ])

        AudioPlayer.addTimeObserver { time in
            self.handleTimeChange(time)
        }
        
        NowPlayingTracks.addTrackChangeObserver { nillableTrack in
            DispatchQueue.main.async { self.handleTrackChange(nillableTrack) }
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    
    private func createTopButtons() -> UIStackView {
        let buttons = UIStackView()
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.axis = .horizontal
        buttons.distribution  = .equalSpacing
        
        let topMiddle = UIStackView()
        topMiddle.translatesAutoresizingMaskIntoConstraints = false
        topMiddle.axis = .horizontal
        topMiddle.distribution  = .equalSpacing

        topMiddle.addArrangedSubview(backIcon)
        topMiddle.addArrangedSubview(playIcon)
        topMiddle.addArrangedSubview(pauseIcon)
        topMiddle.addArrangedSubview(forwardIcon)
                
        buttons.addArrangedSubview(repeatIcon)
        buttons.addArrangedSubview(topMiddle)
        buttons.addArrangedSubview(shuffleIcon)
        
        topMiddle.widthAnchor.constraint(equalToConstant: 145).isActive = true

        return buttons
    }
    
    private func createSongText() -> UIView {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addArrangedSubview(songText)
        
        return view
    }
    
    private func createBottomElements() -> UIStackView {
        let elements = UIStackView()
        elements.translatesAutoresizingMaskIntoConstraints = false
        elements.axis = .horizontal
        elements.distribution  = .fill

        elements.addArrangedSubview(currentTime)
        elements.addArrangedSubview(slider)
        elements.addArrangedSubview(totalTime)

        elements.setCustomSpacing(15.0, after: currentTime)
        elements.setCustomSpacing(15.0, after: slider)
        
        currentTime.widthAnchor.constraint(equalToConstant: 30).isActive = true
        totalTime.widthAnchor.constraint(equalToConstant: 30).isActive = true

        return elements
    }
    
    private func createIcon(
        _ name: String,
        pointSize: Double = 1.5,
        weight: UIImage.SymbolWeight = .ultraLight,
        scale: UIImage.SymbolScale = .small
    ) -> UIImageView {
        let config = UIImage.SymbolConfiguration(pointSize: UIFont.systemFontSize * 1.5, weight: weight, scale: scale)

        let icon = UIImageView(image: UIImage(systemName: name, withConfiguration: config)!)
        icon.isUserInteractionEnabled = true
        icon.tintColor = .white
        
        return icon
    }
    
    private func handleTrackChange(_ nillableTrack: Track?) {
        self.timeListened = 0.0
        self.lastTimeUpdate = 0.0
        self.listenedToCurrentSong = false
        self.playingTrackId = nillableTrack?.id
        
        guard let track = nillableTrack else {
            self.currentTime.text = Formatters.timeFromSeconds(0)
            self.totalTime.text = Formatters.timeFromSeconds(0)
            self.songText.text = " "
            self.slider.setValue(0, animated: true)
            self.pauseIcon.isHidden = true
            self.playIcon.isHidden = false
            
            return
        }
        
        self.currentTime.text = Formatters.timeFromSeconds(0)
        self.totalTime.text = Formatters.timeFromSeconds(Int(track.length))
        self.songText.text = track.name + " - " + track.artist
        self.pauseIcon.isHidden = false
        self.playIcon.isHidden = true
        
        self.slider.setValue(0, animated: true)
        
        self.targetListenTime = Double(Int(track.length)) * 0.60
    }
    
    private func handleTimeChange(_ time: Double) {
        // If the track IDs aren't the same it means we're about to be changing tracks.
        // Ignore setting the slider here or else we will end up with the slider jumping around
        if (self.playingTrackId == nil || self.playingTrackId != NowPlayingTracks.currentTrack?.id) {
            return
        }
        
        // Round the time because that seems to be what the notification area does and it's good if they agree on time
        self.currentTime.text = Formatters.timeFromSeconds(Int(round(time)))
        
        // If we're grabbing the slider avoid updating it visually or it'll skip around while we drag it
        let percentDone = Float(time) / Float(NowPlayingTracks.currentTrack!.length)
        if (!self.sliderGrabbed) {
            self.slider.setValue(percentDone, animated: true)
        }
        
        let timeElapsed = time - self.lastTimeUpdate
        self.lastTimeUpdate = time
        
        // If the time elapsed went negative, or had a large leap forward (more than 1 second), then it means that someone
        // manually altered the song's progress. Do no other checks or updates
        if (timeElapsed < 0 || timeElapsed > 1) {
            return;
        }

        self.timeListened += timeElapsed
        
        if (!self.listenedToCurrentSong && self.timeListened > self.targetListenTime) {
            self.listenedToCurrentSong = true
            TrackState().markTrackListenedTo(NowPlayingTracks.currentTrack!)
        }
        
        if (percentDone >= 1.0) {
            NowPlayingTracks.playNext()
        }
    }
    
    @objc func pauseMusic(tapGestureRecognizer: UITapGestureRecognizer) {
        AudioPlayer.pause()
        self.pauseIcon.isHidden = true
        self.playIcon.isHidden = false
    }
    
    @objc func playMusic(tapGestureRecognizer: UITapGestureRecognizer) {
        if (NowPlayingTracks.currentTrack == nil) {
            return
        }
        
        AudioPlayer.play()
        self.pauseIcon.isHidden = false
        self.playIcon.isHidden = true
    }
    
    @objc func playNext(tapGestureRecognizer: UITapGestureRecognizer) {
        NowPlayingTracks.playNext()
    }
    
    @objc func playPrevious(tapGestureRecognizer: UITapGestureRecognizer) {
        NowPlayingTracks.playPrevious()
    }
    
    @objc func toggleRepeat(tapGestureRecognizer: UITapGestureRecognizer) {
        NowPlayingTracks.repeatOn = !NowPlayingTracks.repeatOn
        repeatIcon.tintColor = NowPlayingTracks.repeatOn ? Colors.aqua : .white
    }
    
    @objc func toggleShuffle(tapGestureRecognizer: UITapGestureRecognizer) {
        NowPlayingTracks.shuffleOn = !NowPlayingTracks.shuffleOn
        shuffleIcon.tintColor = NowPlayingTracks.shuffleOn ? Colors.aqua : .white
    }
    
    @objc func handleSeek(tapGestureRecognizer: UITapGestureRecognizer) {
        if (NowPlayingTracks.currentTrack == nil) {
            return
        }
        
        let seconds = Double(slider.value) * Double(NowPlayingTracks.currentTrack!.length)
        handleTimeChange(seconds)
        AudioPlayer.seekTo(seconds)
    }
    
    @objc func handleSliderGrab(tapGestureRecognizer: UITapGestureRecognizer) {
        sliderGrabbed = true
    }
    
    @objc func handleSliderRelease(tapGestureRecognizer: UITapGestureRecognizer) {
        sliderGrabbed = false
    }
    
    @objc func willEnterForeground() {
        if (AudioPlayer.isPaused) {
            playIcon.isHidden = false
            pauseIcon.isHidden = true
        } else {
            playIcon.isHidden = true
            pauseIcon.isHidden = false
        }
    }
}

extension UIImage {
    // I stole this and converted it from Objective-C
    // https://coffeeshopped.com/2010/09/iphone-how-to-dynamically-color-a-uiimage
    func tinted(color: UIColor) -> UIImage {
        UIGraphicsBeginImageContext(size)

        let context = UIGraphicsGetCurrentContext()!

        context.setFillColor(color.cgColor)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0);

        context.setBlendMode(CGBlendMode.normal)
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        context.draw(self.cgImage!, in: rect)

        context.clip(to: rect, mask: self.cgImage!);
        context.addRect(rect);
        context.drawPath(using: CGPathDrawingMode.fill)

        let coloredImg = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        return coloredImg!
    }
}