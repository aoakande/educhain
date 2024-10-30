;; EduChain Connect Core Smart Contract

;; Define the fungible token for the platform
(define-fungible-token edutoken u1000000000)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-completed (err u103))
(define-constant err-invalid-input (err u104))

;; Data Maps
(define-map institutions 
  { institution-id: uint } 
  { name: (string-ascii 50), address: principal }
)

(define-map address-to-institution-id 
  principal 
  uint
)

(define-map courses 
  { course-id: uint } 
  { name: (string-ascii 100), institution-id: uint, price: uint }
)

(define-map enrollments 
  { student: principal, course-id: uint } 
  { completed: bool }
)

(define-map credentials 
  { credential-id: uint } 
  { student: principal, course-id: uint, institution-id: uint, issued-at: uint }
)

;; Variables
(define-data-var next-institution-id uint u1)
(define-data-var next-course-id uint u1)
(define-data-var next-credential-id uint u1)

;; Functions

;; Register an educational institution
(define-public (register-institution (name (string-ascii 50)))
  (let
    (
      (new-id (var-get next-institution-id))
    )
    (asserts! (> (len name) u0) err-invalid-input)
    (asserts! (is-none (get-institution-id tx-sender)) err-unauthorized)
    (try! (map-set institutions { institution-id: new-id } { name: name, address: tx-sender }))
    (try! (map-set address-to-institution-id tx-sender new-id))
    (var-set next-institution-id (+ new-id u1))
    (ok new-id)
  )
)

;; Create a new course
(define-public (create-course (name (string-ascii 100)) (price uint))
  (let
    (
      (new-id (var-get next-course-id))
      (institution-id (unwrap! (get-institution-id tx-sender) err-unauthorized))
    )
    (asserts! (> (len name) u0) err-invalid-input)
    (asserts! (> price u0) err-invalid-input)
    (try! (map-set courses { course-id: new-id } { name: name, institution-id: institution-id, price: price }))
    (var-set next-course-id (+ new-id u1))
    (ok new-id)
  )
)

;; Enroll in a course
(define-public (enroll-in-course (course-id uint))
  (let
    (
      (course (unwrap! (map-get? courses { course-id: course-id }) err-not-found))
      (institution-address (unwrap! (get-institution-address (get institution-id course)) err-not-found))
    )
    (asserts! (is-none (map-get? enrollments { student: tx-sender, course-id: course-id })) err-unauthorized)
    (try! (stx-transfer? (get price course) tx-sender institution-address))
    (try! (map-set enrollments { student: tx-sender, course-id: course-id } { completed: false }))
    (ok true)
  )
)

;; Complete a course
(define-public (complete-course (course-id uint))
  (let
    (
      (enrollment (unwrap! (map-get? enrollments { student: tx-sender, course-id: course-id }) err-not-found))
    )
    (asserts! (is-some (map-get? courses { course-id: course-id })) err-not-found)
    (asserts! (not (get completed enrollment)) err-already-completed)
    (try! (map-set enrollments { student: tx-sender, course-id: course-id } { completed: true }))
    (ok true)
  )
)

;; Issue a credential
(define-public (issue-credential (student principal) (course-id uint))
  (let
    (
      (course (unwrap! (map-get? courses { course-id: course-id }) err-not-found))
      (enrollment (unwrap! (map-get? enrollments { student: student, course-id: course-id }) err-not-found))
      (institution-id (unwrap! (get-institution-id tx-sender) err-unauthorized))
      (new-id (var-get next-credential-id))
    )
    (asserts! (get completed enrollment) err-unauthorized)
    (asserts! (is-eq (get institution-id course) institution-id) err-unauthorized)
    (try! (map-set credentials 
      { credential-id: new-id } 
      { student: student, course-id: course-id, institution-id: institution-id, issued-at: block-height }
    ))
    (var-set next-credential-id (+ new-id u1))
    (ok new-id)
  )
)

;; Mint and distribute tokens (simplified)
(define-public (distribute-tokens (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-input)
    (asserts! (is-some (get-institution-id recipient)) err-unauthorized)
    (try! (ft-mint? edutoken amount recipient))
    (ok true)
  )
)

;; Helper functions
(define-read-only (get-institution-id (address principal))
  (map-get? address-to-institution-id address)
)

(define-private (get-institution-address (id uint))
  (match (map-get? institutions {institution-id: id})
    institution (some (get address institution))
    none
  )
)

;; Read-only functions
(define-read-only (get-course-details (course-id uint))
  (map-get? courses { course-id: course-id })
)

(define-read-only (get-enrollment-status (student principal) (course-id uint))
  (map-get? enrollments { student: student, course-id: course-id })
)

(define-read-only (get-credential-details (credential-id uint))
  (map-get? credentials { credential-id: credential-id })
)

;; Function to check if an address belongs to a registered institution
(define-read-only (is-institution (address principal))
  (is-some (get-institution-id address))
)
