package com.example.gorillagroove.activities

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.GravityCompat
import com.example.gorillagroove.R
import com.example.gorillagroove.client.loginRequest
import com.example.gorillagroove.db.GroovinDB
import com.example.gorillagroove.db.model.User
import com.example.gorillagroove.db.repository.UserRepository
import com.example.gorillagroove.utils.URLs
import kotlinx.android.synthetic.main.activity_main.drawer_layout
import kotlinx.android.synthetic.main.app_bar_main.toolbar
import kotlinx.android.synthetic.main.content_main.btn_login
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

private const val MainActivityTag = "MainActivity"

class MainActivity : AppCompatActivity(), CoroutineScope by MainScope() {

    private lateinit var userRepository: UserRepository

    private lateinit var passwordField: EditText
    private lateinit var emailField: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        userRepository =
            UserRepository(GroovinDB.getDatabase(this@MainActivity).userRepository())

        runBlocking {
            withContext(Dispatchers.IO) {
                val user = userRepository.lastLoggedInUser()
                Log.i(MainActivityTag, "Last logged in user=$user")
                if (user != null) {
                    startActivity(createPlaylistIntent(user))
                }
            }
        }

        setContentView(R.layout.activity_main)
        setSupportActionBar(toolbar)

        emailField = findViewById(R.id.editText2)
        passwordField = findViewById(R.id.editText)

        emailField.requestFocus()

        btn_login.setOnClickListener {

            val emailFieldText = emailField.text.toString()
            val passwordFieldText = passwordField.text.toString()

            val response =
                runBlocking { loginRequest(URLs.LOGIN, emailFieldText, passwordFieldText) }

            if (!response.has("token")) {
                Toast.makeText(
                    this,
                    "Incorrect login credentials, please try again",
                    Toast.LENGTH_LONG
                ).show()
            } else {
                val token = response["token"].toString()
                val userName = response["username"].toString()
                val email = response["email"].toString()

                findViewById<TextView>(R.id.tv_nav_header).text = userName

                val user = runBlocking {
                    withContext(Dispatchers.IO) {
                        val innerUser: User? = userRepository.findUser(email)

                        if (innerUser != null) {
                            userRepository.updateToken(innerUser.id, token)
                        } else userRepository.createUser(userName, email, token)

                        return@withContext userRepository.findUser(email)
                    }
                }

                emailField.text.clear()
                passwordField.text.clear()
                emailField.requestFocus()
                startActivity(createPlaylistIntent(user!!))
            }
        }
    }

    override fun onBackPressed() {
        if (drawer_layout.isDrawerOpen(GravityCompat.START)) {
            drawer_layout.closeDrawer(GravityCompat.START)
        } else {
            super.onBackPressed()
        }
    }

    private fun createPlaylistIntent(user: User): Intent {
        val intent = Intent(applicationContext, PlaylistActivity::class.java)
        intent.putExtra("token", user.token)
        intent.putExtra("username", user.userName)
        intent.putExtra("email", user.email)
        return intent
    }
}
