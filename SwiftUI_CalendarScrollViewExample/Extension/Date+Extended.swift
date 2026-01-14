//
//  Date;Extended.swift
//  SwiftUI_CalendarScrollViewExample
//
//  Created by cano on 2026/01/14.
//

import Foundation

extension Date {
    /// 現在の基準日から前後合計10ヶ月分のデータを取得します
    /// - 前に5ヶ月、現在の月、後ろに4ヶ月の範囲で構成されます
    var initialLoadMonths: [Month] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        // 表示用のフォーマット（例: "January 2024"）
        formatter.dateFormat = "MMMM yyyy"
        
        var months: [Month] = []
        
        // -5（5ヶ月前）から4（4ヶ月後）までループ
        for offset in -5...4 {
            // カレンダー計算を用いて、月のオフセットを適用した日付を取得
            if let date = calendar.date(byAdding: .month, value: offset, to: self) {
                let monthName = formatter.string(from: date)
                
                // その月の週データ（Weekの配列）を取得
                let weeks = date.weeksInMonth
                
                // Monthオブジェクトを作成して配列に追加
                let month = Month(name: monthName, date: date, weeks: weeks)
                months.append(month)
            }
        }
        
        return months
    }
    
    /// 指定された日付（self）が含まれる月の全週データを抽出します
    /// カレンダーのグリッド表示（日〜土）に合わせた構造を生成します
    var weeksInMonth: [Week] {
        let calendar = Calendar.current
        
        // 1. その月の「開始日〜終了日」の期間を取得
        // 2. その月の「最初の週」が始まる日（前月分を含む場合がある）を取得
        guard let monthInterval = calendar.dateInterval(of: .month, for: self),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }
        
        var weeks: [Week] = []
        // ループの開始点を、その月の第1週の開始曜日（日曜日など）に設定
        var currentDate = monthFirstWeek.start
        
        // カレンダー上の日付が、月の終了時刻を超えるまでループ
        while currentDate < monthInterval.end {
            var days: [Day] = []
            
            // 1週間（7日間）のループ
            for _ in 0..<7 {
                // currentDateが「表示対象の月」に含まれているか判定
                if calendar.isDate(currentDate, equalTo: self, toGranularity: .month) {
                    // 月内の日付であれば、通常の日として追加
                    let value = calendar.component(.day, from: currentDate)
                    let day = Day(value: value, date: currentDate, isPlaceholder: false)
                    days.append(day)
                } else {
                    // 月外の日付（前月の残りや翌月の始まり）はプレースホルダーとして追加
                    days.append(.init(isPlaceholder: true))
                }
                
                // 翌日に進める
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            // 7日分まとまったら「週」として追加
            let week = Week(days: days)
            weeks.append(week)
        }
        
        // 最後の週にフラグを立てる（UI調整用などに便利）
        if let lastIndex = weeks.indices.last {
            weeks[lastIndex].isLast = true
        }
        
        return weeks
    }
}

import Foundation

extension [Month] {
    /// 指定された数だけ、過去または未来の月データを新しく生成します
    /// - Parameters:
    ///   - count: 生成する月の数
    ///   - isPast: trueなら過去方向へ、falseなら未来方向へ生成
    /// - Returns: 生成されたMonthオブジェクトの配列
    func createMonths(_ count: Int, isPast: Bool) -> [Month] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        // 基準となる日付を決定する
        // 過去分を作るならリストの先頭(first)、未来分ならリストの末尾(last)の日付をベースにする
        guard let referenceMonthDate = isPast ? self.first?.date : self.last?.date else {
            return []
        }
        
        var newMonths: [Month] = []
        
        // 指定された数（count）だけループして月を生成
        for index in 1...count {
            // 過去ならマイナス、未来ならプラスのオフセットを計算
            let offset = isPast ? -index : index
            
            // 基準日からオフセット分だけ離れた日付を取得
            if let date = calendar.date(byAdding: .month, value: offset, to: referenceMonthDate) {
                let name = formatter.string(from: date)
                
                // Dateのエクステンション（前回追加分）を使用して週データを生成
                let weeks = date.weeksInMonth
                let month = Month(name: name, date: date, weeks: weeks)
                
                if isPast {
                    // 過去分を生成する場合：
                    // 古い順に並ぶよう、常に配列の先頭（index 0）に挿入する
                    newMonths.insert(month, at: 0)
                } else {
                    // 未来分を生成する場合：
                    // そのまま末尾に追加していく
                    newMonths.append(month)
                }
            }
        }
        
        return newMonths
    }
}
