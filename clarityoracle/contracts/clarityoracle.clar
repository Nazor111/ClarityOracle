;; ClarityOracle - Decentralized Prediction Market
;; Author: Claude
;; Description: A prediction market platform where users can stake tokens on event outcomes

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-event-exists (err u101))
(define-constant err-invalid-outcome (err u102))
(define-constant err-event-not-found (err u103))
(define-constant err-event-concluded (err u104))
(define-constant err-insufficient-stake (err u105))
(define-constant err-not-oracle (err u106))

;; Data Variables
(define-data-var minimum-stake uint u100000) ;; in microSTX
(define-data-var platform-fee uint u25) ;; 0.25% represented as basis points
(define-data-var current-event-id uint u0) ;; Track the current event ID

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
        total-stake: uint
    }
)

(define-map Stakes
    { event-id: uint, staker: principal, outcome: uint }
    { amount: uint }
)

(define-map EventStakes
    { event-id: uint, outcome: uint }
    { total-amount: uint }
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

(define-private (calculate-reward (event-id uint) (outcome uint) (stake-amount uint))
    (match (map-get? Events { event-id: event-id })
        event (let (
            (total-event-stake (get total-stake event))
            (winning-stake (default-to u0 
                (get total-amount 
                    (map-get? EventStakes { event-id: event-id, outcome: outcome }))))
        )
        (if (is-eq winning-stake u0)
            (ok u0)
            (ok (/ (* stake-amount total-event-stake) winning-stake))))
        (err u0)
    )
)

;; Public Functions
(define-public (create-event (title (string-ascii 100)) 
                           (description (string-ascii 500))
                           (oracle principal)
                           (end-block uint)
                           (possible-outcomes (list 10 (string-ascii 50))))
    (let
        (
            (new-event-id (+ (var-get current-event-id) u1))
        )
        (asserts! (is-owner) err-owner-only)
        (asserts! (> (len possible-outcomes) u0) err-invalid-outcome)
        (asserts! (> end-block block-height) err-invalid-outcome)
        
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
                total-stake: u0
            }
        )
        
        ;; Update the current event ID
        (var-set current-event-id new-event-id)
        (ok new-event-id)
    )
)

(define-public (stake (event-id uint) (outcome uint) (amount uint))
    (let (
        (event (unwrap! (map-get? Events { event-id: event-id }) err-event-not-found))
        (current-stake (default-to u0 
            (get amount 
                (map-get? Stakes { event-id: event-id, staker: tx-sender, outcome: outcome }))))
    )
        (asserts! (not (get concluded event)) err-event-concluded)
        (asserts! (>= amount (var-get minimum-stake)) err-insufficient-stake)
        (asserts! (< outcome (len (get possible-outcomes event))) err-invalid-outcome)
        
        ;; Transfer tokens from user to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update stakes
        (map-set Stakes
            { event-id: event-id, staker: tx-sender, outcome: outcome }
            { amount: (+ current-stake amount) }
        )
        
        ;; Update event stakes
        (map-set EventStakes
            { event-id: event-id, outcome: outcome }
            { total-amount: (+ 
                (default-to u0 
                    (get total-amount 
                        (map-get? EventStakes { event-id: event-id, outcome: outcome })))
                amount) }
        )
        
        ;; Update total event stake
        (map-set Events 
            { event-id: event-id }
            (merge event { total-stake: (+ (get total-stake event) amount) })
        )
        
        (ok true)
    )
)

(define-public (conclude-event (event-id uint) (winning-outcome uint))
    (let ((event (unwrap! (map-get? Events { event-id: event-id }) err-event-not-found)))
        (asserts! (is-event-oracle event-id) err-not-oracle)
        (asserts! (not (get concluded event)) err-event-concluded)
        (asserts! (< winning-outcome (len (get possible-outcomes event))) err-invalid-outcome)
        
        ;; Update event as concluded
        (map-set Events
            { event-id: event-id }
            (merge event 
                {
                    concluded: true,
                    winning-outcome: (some winning-outcome)
                }
            )
        )
        (ok true)
    )
)


;; Read-only Functions
(define-read-only (get-event (event-id uint))
    (map-get? Events { event-id: event-id })
)

(define-read-only (get-stake (event-id uint) (staker principal) (outcome uint))
    (map-get? Stakes { event-id: event-id, staker: staker, outcome: outcome })
)

(define-read-only (get-total-stake-for-outcome (event-id uint) (outcome uint))
    (map-get? EventStakes { event-id: event-id, outcome: outcome })
)