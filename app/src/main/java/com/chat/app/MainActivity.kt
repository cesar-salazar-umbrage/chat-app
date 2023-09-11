package com.chat.app

import android.os.Bundle
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import org.json.JSONObject
import java.io.IOException


class MainActivity : AppCompatActivity() {
    private val client = OkHttpClient()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        getStoicMessage("https://api.themotivate365.com/stoic-quote")

    }


    fun getStoicMessage(url: String) {
        val request = Request.Builder()
            .url(url)
            .build()

        val stoicText = findViewById<TextView>(R.id.quote)
        val authorText = findViewById<TextView>(R.id.author)


        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {}
            override fun onResponse(call: Call, response: Response){
                val jsonData: String? = response.body()?.string()
                val jObject = JSONObject(jsonData)
                val quote = jObject.get("quote").toString()
                val author = jObject.get("author").toString()

                stoicText.text = quote
                authorText.text = author

            }
        })
    }
}