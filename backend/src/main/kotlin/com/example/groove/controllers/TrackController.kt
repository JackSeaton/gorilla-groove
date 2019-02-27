package com.example.groove.controllers

import com.example.groove.db.model.Track
import com.example.groove.dto.UpdateTrackDTO
import com.example.groove.dto.YoutubeDownloadDTO
import com.example.groove.services.TrackService
import com.example.groove.services.YoutubeService
import com.example.groove.util.loadLoggedInUser
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.registerKotlinModule

import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import org.springframework.web.multipart.MultipartFile
import java.sql.Timestamp

@RestController
@RequestMapping("api/track")
class TrackController(
		private val trackService: TrackService,
		private val youTubeService: YoutubeService
) {

	//example: http://localhost:8080/api/track?page=0&size=1&sort=name,asc
	@GetMapping
    fun getTracks(
			@RequestParam(value = "userId") userId: Long?,
			@RequestParam(value = "name") name: String?,
			@RequestParam(value = "artist") artist: String?,
			@RequestParam(value = "album") album: String?,
			@RequestParam(value = "searchTerm") searchTerm: String?,
			pageable: Pageable // The page is magic, and allows the frontend to use 3 optional params: page, size, and sort
	): Page<Track> {
		return trackService.getTracks(name, artist, album, userId, searchTerm, pageable)
    }

	// This endpoint is laughably narrow in scope. But I don't know for sure how this is going to evolve later
	@GetMapping("/all-count-since-timestamp")
    fun getAllTrackCountSinceTimestamp(
			@RequestParam(value = "timestamp") unixTimestamp: Long
	): Int {
		return trackService.getAllTrackCountSinceTimestamp(Timestamp(unixTimestamp))
    }

	@PostMapping("/mark-listened")
	fun markSongAsListenedTo(@RequestBody markSongAsReadDTO: MarkTrackAsListenedToDTO): ResponseEntity<String> {
		trackService.markSongListenedTo(markSongAsReadDTO.trackId)

		return ResponseEntity(HttpStatus.OK)
	}

	@PostMapping("/set-hidden")
	fun setHidden(@RequestBody setHiddenDTO: SetHiddenDTO): ResponseEntity<String> {
		trackService.setHidden(setHiddenDTO.trackIds, setHiddenDTO.isHidden)

		return ResponseEntity(HttpStatus.OK)
	}

	@PostMapping("/import")
	fun importTracks(@RequestBody importDTO: MultiTrackIdDTO): List<Track> {
		return trackService.importTrack(importDTO.trackIds)
	}

	// FIXME this should be a PATCH not a PUT. But I was having issues with PATCH failing the OPTIONS check
	// Can't seem to deserialize a multipart file alongside other data using @RequestBody. So this is my dumb solution
	@PutMapping
	fun updateTrackData(
			@RequestParam("albumArt") albumArt: MultipartFile?,
			@RequestParam("updateTrackJson") updateTrackJson: String
	): ResponseEntity<String> {
		val mapper = ObjectMapper().registerKotlinModule()
		val updateTrackDTO = mapper.readValue(updateTrackJson, UpdateTrackDTO::class.java)

		trackService.updateTracks(loadLoggedInUser(), updateTrackDTO, albumArt)

		return ResponseEntity(HttpStatus.OK)
	}

	@DeleteMapping
	fun deleteTracks(@RequestBody deleteTrackDTO: MultiTrackIdDTO): ResponseEntity<String> {
		trackService.deleteTracks(loadLoggedInUser(), deleteTrackDTO.trackIds)

		return ResponseEntity(HttpStatus.OK)
	}

	@PostMapping("/youtube-dl")
	fun youtubeDownload(@RequestBody youTubeDownloadDTO: YoutubeDownloadDTO): Track {
		if (youTubeDownloadDTO.url.contains("&list")) {
			throw IllegalArgumentException("Playlist downloads are not allowed")
		}

		return youTubeService.downloadSong(youTubeDownloadDTO)
	}

	data class MarkTrackAsListenedToDTO(
			val trackId: Long
	)

	data class SetHiddenDTO(
			val trackIds: List<Long>,
			val isHidden: Boolean
	)

	data class MultiTrackIdDTO(
			val trackIds: List<Long>
	)


}
