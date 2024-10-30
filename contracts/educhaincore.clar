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
    (map-set institutions { institution-id: new-id } { name: name, address: tx-sender })
    (map-set address-to-institution-id tx-sender new-id)
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
    (map-set courses { course-id: new-id } { name: name, institution-id: institution-id, price: price })
    (var-set next-course-id (+ new-id u1))
    (ok new-id)
  )
)

;; Enroll in a course
(define-public (enroll-in-course (course-id uint))
  (let
    (
      (course (map-get? courses { course-id: course-id }))
    )
    ;; Check if the course exists
    (asserts! (is-some course) err-not-found)
    (let
      (
        (unwrapped-course (unwrap! course err-not-found))
        (institution-address (get-institution-address (get institution-id unwrapped-course)))
      )
      ;; Check if the student is not already enrolled
      (asserts! (is-none (map-get? enrollments { student: tx-sender, course-id: course-id })) err-unauthorized)
      (try! (stx-transfer? (get price unwrapped-course) tx-sender (unwrap! institution-address err-not-found)))
      (ok (map-set enrollments { student: tx-sender, course-id: course-id } { completed: false }))
    )
  )
)

;; Complete a course
(define-public (complete-course (course-id uint))
  (let
    (
      (enrollment (map-get? enrollments { student: tx-sender, course-id: course-id }))
    )
    ;; Check if the course exists
    (asserts! (is-some (map-get? courses { course-id: course-id })) err-not-found)
    ;; Check if the student is enrolled
    (asserts! (is-some enrollment) err-not-found)
    (let
      (
        (unwrapped-enrollment (unwrap! enrollment err-not-found))
      )
      ;; Check if the course hasn't been completed yet
      (asserts! (not (get completed unwrapped-enrollment)) err-already-completed)
      (ok (map-set enrollments { student: tx-sender, course-id: course-id } { completed: true }))
    )
  )
)

;; Issue a credential
(define-public (issue-credential (student principal) (course-id uint))
  (let
    (
      (course (map-get? courses { course-id: course-id }))
      (enrollment (map-get? enrollments { student: student, course-id: course-id }))
      (institution-id (get-institution-id tx-sender))
    )
    ;; Check if the course exists
    (asserts! (is-some course) err-not-found)
    ;; Check if the student is enrolled
    (asserts! (is-some enrollment) err-not-found)
    ;; Check if the issuer is an institution
    (asserts! (is-some institution-id) err-unauthorized)
    (let
      (
        (unwrapped-course (unwrap! course err-not-found))
        (unwrapped-enrollment (unwrap! enrollment err-not-found))
        (unwrapped-institution-id (unwrap! institution-id err-unauthorized))
        (new-id (var-get next-credential-id))
      )
      ;; Check if the course has been completed
      (asserts! (get completed unwrapped-enrollment) err-unauthorized)
      ;; Check if the issuer is the institution that owns the course
      (asserts! (is-eq (get institution-id unwrapped-course) unwrapped-institution-id) err-unauthorized)
      (map-set credentials 
        { credential-id: new-id } 
        { student: student, course-id: course-id, institution-id: unwrapped-institution-id, issued-at: block-height }
      )
      (var-set next-credential-id (+ new-id u1))
      (ok new-id)
    )
  )
)

;; Mint and distribute tokens (simplified)
(define-public (distribute-tokens (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-input)
    ;; Check if the recipient is a valid principal
    (asserts! (is-some (get-institution-id recipient)) err-unauthorized)
    (ft-mint? edutoken amount recipient)
  )
)

;; Helper functions
(define-read-only (get-institution-id (address principal))
  (map-get? address-to-institution-id address)
)

(define-private (get-institution-address (id uint))
  (match (map-get? institutions {institution-id: id})
    institution (ok (get address institution))
    err-not-found
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
