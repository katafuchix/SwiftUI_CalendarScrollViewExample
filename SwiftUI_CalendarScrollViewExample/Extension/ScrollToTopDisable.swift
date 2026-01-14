//
//  ScrollToTopDisable.swift
//  SwiftUI_CalendarScrollViewExample
//
//  Created by cano on 2026/01/14.
//

import SwiftUI

/// SwiftUIのビュー階層から親のUIScrollViewを探し出し、
/// 「ステータスバータップでトップに戻る(scrollsToTop)」機能を無効化するためのヘルパービューです。
struct ScrollToTopDisable: UIViewRepresentable {
    
    func makeUIView(context: Context) -> UIView {
        // 1. 透明で目立たない空のUIViewを作成
        let view = UIView()
        view.backgroundColor = .clear
        
        // 2. ビューが画面に追加された直後に実行されるよう、メインスレッドで非同期処理を行う
        DispatchQueue.main.async {
            // 3. SwiftUIの内部的なビュー階層を辿って、目的のUIScrollViewを探索する
            // 注意: この階層構造（superview...）はSwiftUIの内部実装に依存しているため、
            // OSのアップデート等で動作が変わる可能性があります。
            if let scrollView = view.superview?.superview?.subviews.last?.subviews.first as? UIScrollView {
                // 4. ステータスバータップ時の自動スクロールをオフにする
                scrollView.scrollsToTop = false
            }
        }
        
        return view
    }
    
    /// 更新時の処理は不要なため空にしています
    func updateUIView(_ uiView: UIView, context: Context) {  }
}
