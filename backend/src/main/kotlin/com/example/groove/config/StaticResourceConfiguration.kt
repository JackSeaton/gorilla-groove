package com.example.groove.config

import com.example.groove.properties.MusicProperties
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.context.annotation.Configuration
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer


@Configuration
class StaticResourceConfiguration @Autowired constructor(
		private val musicProperties: MusicProperties
): WebMvcConfigurer {
	override fun addResourceHandlers(registry: ResourceHandlerRegistry) {
		// Create an authenticated path for the frontend to grab songs from
		registry
				.addResourceHandler("/music/**")
				.addResourceLocations("file:${musicProperties.musicDirectoryLocation}")
	}
}