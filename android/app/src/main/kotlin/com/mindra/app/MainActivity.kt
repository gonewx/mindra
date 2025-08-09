package com.mindra.app

import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import android.graphics.Color
import android.view.WindowManager

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // 设置窗口背景色，确保在Flutter加载前就显示 - 使用应用主色调
        window.decorView.setBackgroundColor(Color.parseColor("#2E3B82"))
        
        // 优化启动性能
        window.setFlags(
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        )
        
        super.onCreate(savedInstanceState)
    }
}
