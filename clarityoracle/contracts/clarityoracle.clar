;; ClarityOracle - Enhanced Cross-Chain Prediction Market
;; Description: A prediction market platform with cross-chain support, multi-asset staking, and NFT rewards

;; Define fungible token trait
(define-trait ft-trait
    (
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))
        (get-balance (principal) (response uint uint))
        (get-decimals () (response uint uint))
        (get-name () (response (string-ascii 32) uint))
        (get-symbol () (response (string-ascii 32) uint))
        (get-token-uri () (response (optional (string-utf8 256)) uint))
    )
)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-event-exists (err u101))
(define-constant err-invalid-outcome (err u102))
(define-constant err-event-not-found (err u103))
(define-constant err-event-concluded (err u104))
(define-constant err-insufficient-stake (err u105))
(define-constant err-not-oracle (err u106))
(define-constant err-invalid-token (err u107))
(define-constant err-token-transfer-failed (err u108))
(define-constant err-invalid-bridge (err u109))
(define-constant err-unauthorized (err u110))
(define-constant err-invalid-rate (err u111))
(define-constant err-invalid-chain-id (err u112))

;; Data Variables
(define-data-var minimum-stake uint u100000) ;; in microSTX
(define-data-var platform-fee uint u25) ;; 0.25% represented as basis points
(define-data-var current-event-id uint u0)
(define-data-var current-nft-id uint u0)

;; Data Maps
(define-map Events
    { event-id: uint }
    {
        title: (string-ascii 100),
        description: (string-ascii 500),
        creator: principal,
        oracle: principal,
        end-block: uint,
        possible-outcomes: (list 10 (string-ascii 50)),
        concluded: bool,
        winning-outcome: (optional uint),
        total-stake: uint,
        supported-tokens: (list 10 principal),
        cross-chain-verification: (optional (string-ascii 100))
    }
)

(define-map Stakes
    { event-id: uint, staker: principal, outcome: uint }
    {
        amount: uint,
        token: principal,
        original-amount: uint
    }
)

(define-map EventStakes
    { event-id: uint, outcome: uint, token: principal }
    { total-amount: uint }
)

(define-map TokenRates
    { token: principal }
    { rate: uint } ;; Rate in basis points (1 = 0.01%)
)

(define-map UserAchievements
    { user: principal }
    {
        correct-predictions: uint,
        total-stake-amount: uint,
        nft-rewards: (list 10 uint)
    }
)

(define-map CrossChainBridges
    { chain-id: (string-ascii 20) }
    {
        bridge-contract: principal,
        oracle: principal,
        enabled: bool
    }
)

;; Private Functions
(define-private (is-owner)
    (is-eq tx-sender contract-owner)
)

(define-private (is-event-oracle (event-id uint))
    (match (map-get? Events { event-id: event-id })
        event (is-eq tx-sender (get oracle event))
        false
    )
)

(define-private (convert-to-stx (amount uint) (token principal))
    (match (map-get? TokenRates { token: token })
        rate (ok (/ (* amount (get rate rate)) u10000))
        (err err-invalid-token)
    )
)

(define-private (mint-achievement-nft (recipient principal) (achievement-type uint))
    (let
        (
            (nft-id (+ (var-get current-nft-id) u1))
        )
        (var-set current-nft-id nft-id)
        ;; Here you would implement the actual NFT minting logic
        (ok nft-id)
    )
)

;; Read-only function for getting stake information
(define-read-only (get-stake (event-id uint) (staker principal) (outcome uint))
    (map-get? Stakes { event-id: event-id, staker: staker, outcome: outcome })
)

;; Public Functions
(define-public (register-token (token principal) (rate uint))
    (begin
        (asserts! (is-owner) err-owner-only)
        (asserts! (> rate u0) err-invalid-rate)
        (ok (map-set TokenRates { token: token } { rate: rate }))
    )
)

(define-public (register-bridge (chain-id (string-ascii 20)) 
                              (bridge-contract principal)
                              (oracle principal))
    (begin
        (asserts! (is-owner) err-owner-only)
        (asserts! (> (len chain-id) u0) err-invalid-chain-id)
        (ok (map-set CrossChainBridges
            { chain-id: chain-id }
            {
                bridge-contract: bridge-contract,
                oracle: oracle,
                enabled: true
            }
        ))
    )
)

(define-public (create-cross-chain-event 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (oracle principal)
    (end-block uint)
    (possible-outcomes (list 10 (string-ascii 50)))
    (supported-tokens (list 10 principal))
    (cross-chain-verification (optional (string-ascii 100))))
    
    (let
        (
            (new-event-id (+ (var-get current-event-id) u1))
        )
        (asserts! (is-owner) err-owner-only)
        (asserts! (> (len possible-outcomes) u0) err-invalid-outcome)
        (asserts! (> end-block block-height) err-invalid-outcome)
        (asserts! (> (len title) u0) err-invalid-outcome)
        (asserts! (> (len description) u0) err-invalid-outcome)
        
        (ok (begin
            (map-set Events
                { event-id: new-event-id }
                {
                    title: title,
                    description: description,
                    creator: tx-sender,
                    oracle: oracle,
                    end-block: end-block,
                    possible-outcomes: possible-outcomes,
                    concluded: false,
                    winning-outcome: none,
                    total-stake: u0,
                    supported-tokens: supported-tokens,
                    cross-chain-verification: cross-chain-verification
                }
            )
            (var-set current-event-id new-event-id)
            new-event-id
        ))
    )
)

(define-public (stake-with-token 
    (event-id uint) 
    (outcome uint) 
    (amount uint)
    (token <ft-trait>))
    
    (let
        (
            (event (unwrap! (map-get? Events { event-id: event-id }) err-event-not-found))
            (token-principal (contract-of token))
            (stx-amount (unwrap! (convert-to-stx amount token-principal) err-invalid-token))
            (current-stake (default-to 
                { amount: u0, token: token-principal, original-amount: u0 }
                (map-get? Stakes { event-id: event-id, staker: tx-sender, outcome: outcome })))
        )
        (asserts! (not (get concluded event)) err-event-concluded)
        (asserts! (>= stx-amount (var-get minimum-stake)) err-insufficient-stake)
        (asserts! (< outcome (len (get possible-outcomes event))) err-invalid-outcome)
        
        ;; Transfer tokens using trait
        (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
        
        ;; Update stakes
        (map-set Stakes
            { event-id: event-id, staker: tx-sender, outcome: outcome }
            {
                amount: (+ (get amount current-stake) stx-amount),
                token: token-principal,
                original-amount: (+ (get original-amount current-stake) amount)
            }
        )
        
        ;; Update event stakes
        (map-set EventStakes
            { event-id: event-id, outcome: outcome, token: token-principal }
            { total-amount: (+ 
                (default-to u0 
                    (get total-amount 
                        (map-get? EventStakes { event-id: event-id, outcome: outcome, token: token-principal })))
                stx-amount) }
        )
        
        ;; Update total event stake
        (map-set Events 
            { event-id: event-id }
            (merge event { total-stake: (+ (get total-stake event) stx-amount) })
        )
        
        (ok true)
    )
)

(define-public (claim-rewards (event-id uint))
    (let
        (
            (event (unwrap! (map-get? Events { event-id: event-id }) err-event-not-found))
            (winning-outcome (unwrap! (get winning-outcome event) err-event-not-found))
            (stake (unwrap! (get-stake event-id tx-sender winning-outcome) err-event-not-found))
        )
        
        ;; Update achievements
        (match (map-get? UserAchievements { user: tx-sender })
            achievement
            (ok (map-set UserAchievements
                { user: tx-sender }
                {
                    correct-predictions: (+ (get correct-predictions achievement) u1),
                    total-stake-amount: (+ (get total-stake-amount achievement) (get amount stake)),
                    nft-rewards: (get nft-rewards achievement)
                }
            ))
            (ok (map-set UserAchievements
                { user: tx-sender }
                {
                    correct-predictions: u1,
                    total-stake-amount: (get amount stake),
                    nft-rewards: (list)
                }
            ))
        )
    )
)

;; Read-only Functions
(define-read-only (get-token-rate (token principal))
    (map-get? TokenRates { token: token })
)

(define-read-only (get-user-achievements (user principal))
    (map-get? UserAchievements { user: user })
)

(define-read-only (get-bridge-info (chain-id (string-ascii 20)))
    (map-get? CrossChainBridges { chain-id: chain-id })
)