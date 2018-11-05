package com.example.groove.db.model

import com.fasterxml.jackson.annotation.JsonIgnore
import java.sql.Timestamp
import java.util.*
import javax.persistence.*

@Entity
data class Track(

		@Id
		@GeneratedValue(strategy = GenerationType.IDENTITY)
		val id: Long = 0,

		@Column(nullable = false)
		var name: String,

		@Column(nullable = false)
		var artist: String = "",

		@Column(nullable = false)
		var album: String = "",

		@Column(name = "file_name", nullable = false)
		var fileName: String,

		@Column(name = "bit_rate", nullable = false)
		var bitRate: Long,

		@Column(name = "sample_rate", nullable = false)
		var sampleRate: Int,

		@Column(nullable = false)
		var length: Int,

		@Column(name = "release_year")
		var releaseYear: Int? = null,

		@JsonIgnore
		@Column(name = "created_at", nullable = false)
		var createdAt: Timestamp = Timestamp(Date().time)
)