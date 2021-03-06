import UIKit
import Foundation

class TrackViewCell: UITableViewCell {
    
    var track: ViewableTrackData? {
        didSet {
            guard let track = track else {return}
            
            nameLabel.text = track.name.isEmpty ? " " : track.name
            artistLabel.text = track.artistString.isEmpty ? " " : track.artistString.uppercased()
            albumLabel.text = track.album.isEmpty ? " " : track.album
            
            durationLabel.text = Formatters.timeFromSeconds(Int(track.length))
            
            nameLabel.sizeToFit()
            artistLabel.sizeToFit()
            albumLabel.sizeToFit()
        }
    }
    
    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = Colors.tableText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let artistLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 10)
        label.textColor = Colors.artistDisplay
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let albumLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textColor = Colors.songDisplay
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let durationLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 12)
        label.textColor = Colors.artistDisplay
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    func checkIfPlaying(idToCheckAgainst: Int? = NowPlayingTracks.currentTrack?.id) {
        if (track != nil && track?.id == idToCheckAgainst) {
            artistLabel.textColor = Colors.primary
            nameLabel.textColor = Colors.playingSongtitle
            albumLabel.textColor = Colors.primary
        } else {
            artistLabel.textColor = Colors.songDisplay
            nameLabel.textColor = Colors.tableText
            albumLabel.textColor = Colors.songDisplay
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        let containerView = UIStackView()
        containerView.axis = .vertical
        containerView.distribution  = .fill
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.distribution  = .equalSpacing
        topRow.alignment = .fill
        topRow.translatesAutoresizingMaskIntoConstraints = false
        
        topRow.addArrangedSubview(artistLabel)
        topRow.addArrangedSubview(durationLabel)
        
        containerView.addArrangedSubview(topRow)
        containerView.addArrangedSubview(nameLabel)
        containerView.addArrangedSubview(albumLabel)
        
        containerView.setCustomSpacing(6.0, after: topRow)
        containerView.setCustomSpacing(8.0, after: nameLabel)

        self.contentView.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -16),
            artistLabel.widthAnchor.constraint(equalTo: topRow.widthAnchor, constant: -40),
            topRow.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            
            self.contentView.heightAnchor.constraint(equalTo: containerView.heightAnchor, constant: 10)
        ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

protocol ViewableTrackData {
    var id: Int { get set }
    var name: String { get set }
    var artistString: String { get }
    var album: String { get set }
    var length: Int { get set }
}
