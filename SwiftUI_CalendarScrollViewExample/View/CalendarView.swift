//
//  CalendarView.swift
//  SwiftUI_CalendarScrollViewExample
//
//  Created by cano on 2026/01/14.
//

import SwiftUI

// 1ヶ月分の表示高さ（スクロール計算の基準値）
let monthHeight: CGFloat = 400

struct CalendarView: View {
    // カレンダーに表示する月のデータ配列
    @State private var months: [Month] = []
    // iOS 17+ の新しいスクロール位置制御オブジェクト
    @State private var scrollPosition: ScrollPosition = .init()
    
    /// 無限スクロールのためのフラグ管理
    @State private var isLoadingTop: Bool = false    // 過去方向のロード中か
    @State private var isLoadingBottom: Bool = false // 未来方向のロード中か
    @State private var isResetting: Bool = false     // 「Today」リセット処理中か
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                // 月データの数だけループしてビューを生成
                ForEach(months) { month in
                    MonthView(month: month)
                        .frame(height: monthHeight)
                }
            }
        }
        // State変数 scrollPosition とスクロール位置をバインド
        .scrollPosition($scrollPosition)
        // 初期表示位置を（上端ではなく）中央付近に設定
        .defaultScrollAnchor(.center)
        // iOS 18+ の新API: スクロール中のジオメトリ（位置・サイズ）変化を監視
        .onScrollGeometryChange(for: ScrollInfo.self, of: {
            // スクロールのオフセット（現在の表示位置）を算出
            let offsetY = $0.contentOffset.y + $0.contentInsets.top
            // コンテンツ全体の高さ
            let contentHeight = $0.contentSize.height
            // スクロールビュー自体の表示高さ
            let containerHeight = $0.containerSize.height
            
            return .init(
                offsetY: offsetY,
                contentHeight: contentHeight,
                containerHeight: containerHeight
            )
        }, action: { oldValue, newValue in
            // 月データが揃っていない、またはリセット処理中は無限スクロール処理をスキップ
            guard months.count >= 10 && !isResetting else { return }
            
            let threshold: CGFloat = 100 // 端からどれくらい近づいたら読み込むかの閾値
            let offsetY = newValue.offsetY
            let contentHeight = newValue.contentHeight
            let frameHeight = newValue.containerHeight
            
            // 下端に近づいた判定：未来の月をロード
            if offsetY > (contentHeight - frameHeight - threshold) && !isLoadingBottom {
                loadFutureMonths(info: newValue)
            }
            
            // 上端に近づいた判定：過去の月をロード
            if offsetY < threshold && !isLoadingTop {
                loadPastMonths(info: newValue)
            }
        })
        /// オプション設定（スクロールバー非表示、特殊なスクロール戻り無効化など）
        .scrollIndicators(.hidden)
        .background(ScrollToTopDisable()) // ステータスバータップでのトップ戻りを防止
        .compositingGroup()
        /// オプション終了
        // 画面上部に曜日の見出し（SymbolView）を固定
        .safeAreaInset(edge: .top, spacing: 0) {
            SymbolView()
        }
        // 画面下部に操作バー（BottomBar）を配置
        .overlay(alignment: .bottom) {
            //BottomBar() // デバッグ用
        }
        .onAppear {
            // 初回表示時にデータがなければロードを開始
            guard months.isEmpty else { return }
            loadInitialData()
        }
    }
    
    /// 曜日見出しビュー（Sun, Mon, ...）
    @ViewBuilder
    func SymbolView() -> some View {
        HStack(spacing: 0) {
            // カレンダー設定から曜日の記号を自動取得してループ
            ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 15)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .background(.ultraThinMaterial) // 背景を透過ぼかしに設定
    }
    
    /// ボトムバー（Todayボタンとデータ数表示）
    @ViewBuilder
    func BottomBar() -> some View {
        HStack {
            Button {
                // 「Today」に戻るためのリセット処理
                isResetting = true
                loadInitialData()
                DispatchQueue.main.async {
                    isResetting = false
                }
            } label: {
                Text("Today")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.background, in: .capsule)
            }
            
            Spacer(minLength: 0)
            
            // 現在のメモリ上の月データを表示（デバッグ用）
            Text("Array Count: \(months.count)")
                .fontWeight(.semibold)
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.background, in: .capsule)
            
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        /// iOS 18以降でサポートされるプログレスビューのようなぼかし背景エフェクト
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask {
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.7),
                            Color.white,
                            Color.white,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .padding(.top, -30)
                .ignoresSafeArea()
        }
    }
    
    /// 未来の月データを追加ロードする
    private func loadFutureMonths(info: ScrollInfo) {
        isLoadingBottom = true
        // 10ヶ月分の未来データを生成して配列の末尾に追加
        let futureMonths = months.createMonths(10, isPast: false)
        months.append(contentsOf: futureMonths)
        
        // 配列が長くなりすぎないよう、30ヶ月を超えたら上端（過去分）を10個削除
        if months.count > 30 {
            adjustScrollContentOffset(removesTop: true, info: info)
        }
        
        // メインスレッドでロード中フラグを解除（連続実行を防止）
        DispatchQueue.main.async {
            isLoadingBottom = false
        }
    }
    
    /// 過去の月データを追加ロードする
    private func loadPastMonths(info: ScrollInfo) {
        isLoadingTop = true
        // 10ヶ月分の過去データを生成して配列の先頭に挿入
        let pastMonths = months.createMonths(10, isPast: true)
        months.insert(contentsOf: pastMonths, at: 0)
        
        // 配列の先頭にデータが入るとスクロール位置がズレるため、即座にオフセットを補正
        adjustScrollContentOffset(removesTop: false, info: info)
        
        DispatchQueue.main.async {
            isLoadingTop = false
        }
    }
    
    /// データ増減時にスクロールの見た目上の位置が飛ばないよう補正する処理
    private func adjustScrollContentOffset(removesTop: Bool, info: ScrollInfo) {
        let previousContentHeight = info.contentHeight
        let previousOffset = info.offsetY
        // 10個分（10ヶ月分）の高さ合計
        let adjustmentHeight: CGFloat = monthHeight * 10
        
        if removesTop {
            // 上端を削除する場合
            months.removeFirst(10)
        } else {
            // 下端を削除する場合（全体の数が30を超えている時のみ）
            if months.count > 30 { months.removeLast(10) }
        }
        
        // 削除・追加後の新しいコンテンツ高さとオフセットを計算
        let newContentHeight = previousContentHeight + (removesTop ? -adjustmentHeight : adjustmentHeight)
        let newContentOffset = previousOffset + (newContentHeight - previousContentHeight)
        
        // スクロールの慣性（Velocity）を維持したまま位置を更新
        var transaction = Transaction()
        transaction.scrollPositionUpdatePreservesVelocity = true
        withTransaction(transaction) {
            scrollPosition.scrollTo(y: newContentOffset)
        }
    }
    
    /// 初回起動時のデータ読み込み
    private func loadInitialData() {
        // 現在日を基準に初期データをロード
        months = Date.now.initialLoadMonths
        /// 全体のちょうど真ん中にスクロール位置を初期化
        let centerOffset = (CGFloat(months.count / 2) * monthHeight) - (monthHeight / 2)
        scrollPosition.scrollTo(y: centerOffset)
    }
}

/// 1ヶ月分のビュー
struct MonthView: View {
    var month: Month
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 月の名前（例: January 2024）
            Text(month.name)
                .font(.title2)
                .fontWeight(.bold)
                .frame(height: 50, alignment: .bottom)
            
            /// 週のリストを表示
            VStack(spacing: 0) {
                ForEach(month.weeks) { week in
                    HStack(spacing: 0) {
                        /// 日のリストを表示
                        ForEach(week.days) { day in
                            DayView(day: day)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .bottom) {
                        // 最後の週でなければ、週の境界線を表示
                        if !week.isLast {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 15)
    }
}

/// 1日分のビュー
struct DayView: View {
    var day: Day
    var body: some View {
        // 有効な日付であり、プレースホルダーでない場合
        if let dayValue = day.value, let date = day.date, !day.isPlaceholder {
            let isToday = Calendar.current.isDateInToday(date)
            
            Text("\(dayValue)")
                .font(.callout)
                .fontWeight(isToday ? .semibold : .regular)
                .foregroundStyle(isToday ? .white : .primary)
                .frame(width: 30, height: 50)
                .background {
                    // 今日の場合は青い丸を表示
                    if isToday {
                        Circle()
                            .fill(.blue.gradient)
                    }
                }
                .frame(maxWidth: .infinity)
        } else {
            // 月の前後にある空枠
            Color.clear
        }
    }
}

#Preview {
    ContentView()
}
