//
//  ViewController.swift
//  LowLotencyStreamViewer
//
//  Created by USER on 3/26/25.
//

import UIKit
import AVFoundation
import AVKit

class ViewController: UIViewController {
    
    // UI 요소
    private let playerView = UIView()
    private let latencyLabel = UILabel()
    private let bufferSizeSlider = UISlider()
    private let bufferValueLabel = UILabel()
    private let startButton = UIButton(type: .system)
    
    // 플레이어 및 컨트롤러
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    
    // 모니터링 변수
    private var startTime: Date?
    
    // HLS 스트림 URL - 실제 테스트 스트림으로 교체하세요
    private let hlsStreamURL = URL(string: "https://bitdash-a.akamaihd.net/content/MI201109210084_1/m3u8s/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.m3u8")!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        // 플레이어 뷰
        playerView.backgroundColor = .black
        view.addSubview(playerView)
        
        // 지연시간 표시
        latencyLabel.text = "지연시간: -- ms"
        latencyLabel.textAlignment = .center
        view.addSubview(latencyLabel)
        
        // 버퍼 크기 컨트롤
        bufferSizeSlider.minimumValue = 0.5
        bufferSizeSlider.maximumValue = 10.0
        bufferSizeSlider.value = 3.0
        bufferSizeSlider.addTarget(self, action: #selector(bufferSizeChanged), for: .valueChanged)
        view.addSubview(bufferSizeSlider)
        
        bufferValueLabel.text = "버퍼: 3.0초"
        bufferValueLabel.textAlignment = .center
        view.addSubview(bufferValueLabel)
        
        // 시작 버튼
        startButton.setTitle("HLS 스트림 시작", for: .normal)
        startButton.addTarget(self, action: #selector(startStreamButtonTapped), for: .touchUpInside)
        view.addSubview(startButton)
    }
    
    private func setupConstraints() {
        playerView.translatesAutoresizingMaskIntoConstraints = false
        latencyLabel.translatesAutoresizingMaskIntoConstraints = false
        bufferSizeSlider.translatesAutoresizingMaskIntoConstraints = false
        bufferValueLabel.translatesAutoresizingMaskIntoConstraints = false
        startButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // 플레이어 뷰
            playerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            playerView.heightAnchor.constraint(equalTo: playerView.widthAnchor, multiplier: 9/16),
            
            // 지연시간 표시
            latencyLabel.topAnchor.constraint(equalTo: playerView.bottomAnchor, constant: 20),
            latencyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // 버퍼 크기 컨트롤
            bufferSizeSlider.topAnchor.constraint(equalTo: latencyLabel.bottomAnchor, constant: 20),
            bufferSizeSlider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bufferSizeSlider.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
            
            bufferValueLabel.topAnchor.constraint(equalTo: bufferSizeSlider.bottomAnchor, constant: 10),
            bufferValueLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // 시작 버튼
            startButton.topAnchor.constraint(equalTo: bufferValueLabel.bottomAnchor, constant: 30),
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 150),
            startButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - 액션
    
    @objc private func bufferSizeChanged(_ sender: UISlider) {
        let value = round(sender.value * 10) / 10
        bufferValueLabel.text = "버퍼: \(value)초"
        
        // 버퍼 사이즈가 변경되면 재생 중인 스트림에도 적용
        if let playerItem = playerItem {
            playerItem.preferredForwardBufferDuration = TimeInterval(value)
        }
    }
    
    @objc private func startStreamButtonTapped() {
        stopPlayback()
        startPlayback()
    }
    
    // MARK: - 재생 제어
    
    private func startPlayback() {
        // 저지연을 위한 AVPlayer 구성
        let asset = AVURLAsset(url: hlsStreamURL)
        playerItem = AVPlayerItem(asset: asset)
        
        // AVPlayer 관련 알림 등록
        setupPlayerObservers()
        
        // 슬라이더 값에 따라 선호하는 버퍼 크기 설정
        playerItem?.preferredForwardBufferDuration = TimeInterval(bufferSizeSlider.value)
        
        // HLS 특정 옵션 설정
        let preferredForwardBufferDuration = TimeInterval(bufferSizeSlider.value)
        playerItem?.preferredForwardBufferDuration = preferredForwardBufferDuration
        
        // AVPlayer 초기화 및 레이어 설정
        player = AVPlayer(playerItem: playerItem)
        
        playerLayer?.removeFromSuperlayer()
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.frame = playerView.bounds
        playerView.layer.addSublayer(playerLayer!)
        
        // 재생 시작
        player?.play()
        
        // 모니터링 시작
        startMonitoring()
    }
    
    private func setupPlayerObservers() {
        // 재생 상태 변화 관찰
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidPlayToEndTime),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemFailedToPlayToEndTime),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )
    }
    
    private func stopPlayback() {
        player?.pause()
        
        // 관찰자 제거
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        
        player = nil
        playerItem = nil
        stopMonitoring()
    }
    
    // MARK: - 플레이어 알림 핸들러
    
    @objc private func playerItemDidPlayToEndTime(_ notification: Notification) {
        // 재생 완료 처리
    }
    
    @objc private func playerItemFailedToPlayToEndTime(_ notification: Notification) {
        // 재생 실패 처리
    }
    
    // MARK: - 성능 모니터링
    
    private func startMonitoring() {
        stopMonitoring()
        
        startTime = Date()
        
        // 주기적으로 지연시간 업데이트
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateLatencyStats()
        }
    }
    
    private func stopMonitoring() {
        startTime = nil
    }
    
    private func updateLatencyStats() {
        guard let playerItem = playerItem else { return }
        
        // 예상 지연시간 계산 및 표시
        // 버퍼 크기를 기반으로 지연시간 추정
        let bufferSize = Double(bufferSizeSlider.value)
        
        // 실제 로드된 시간 범위 확인
        let loadedRanges = playerItem.loadedTimeRanges
        var loadedDuration: TimeInterval = 0
        
        if let timeRange = loadedRanges.first?.timeRangeValue {
            loadedDuration = timeRange.duration.seconds
        }
        
        // 현재 재생 상태 확인
        let isBuffering = !playerItem.isPlaybackLikelyToKeepUp
        
        // 실제 스트리밍 지연시간 추정 - 버퍼 크기와 현재 버퍼 상태를 고려
        var estimatedLatency = bufferSize
        
        // 버퍼링 중이면 추가 지연 고려
        if isBuffering {
            estimatedLatency += 1.0
        }
        
        // 실제 로드된 시간이 설정된 버퍼보다 작으면 그 값 사용
        if loadedDuration > 0 && loadedDuration < bufferSize {
            estimatedLatency = loadedDuration
        }
        
        // UI 업데이트
        DispatchQueue.main.async { [weak self] in
            self?.latencyLabel.text = "예상 지연시간: \(Int(estimatedLatency * 1000)) ms"
            
            // 지연시간에 따른 색상 코드
            if estimatedLatency < 1.0 {
                self?.latencyLabel.textColor = .green
            } else if estimatedLatency < 3.0 {
                self?.latencyLabel.textColor = .orange
            } else {
                self?.latencyLabel.textColor = .red
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = playerView.bounds
    }
}
