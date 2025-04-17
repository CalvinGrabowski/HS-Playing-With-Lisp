

; note format

; defun defines functions which can be used by the user or in other functions

(defun talk ()

  (format t "Hello my friend")
  (format t ". This doesn't make a new line")
  (format t "~%can I need to compile whenever I change something")

  (let ((x 0))
    (loop for i from 1 to 12 do
          (print i))
    
    (print x))
  
  )

(defun factorial (n)

  (if (<= n 1)
      1               ; this is a return statement basically saying that if n is not greater than 1 it will return 1
      (* n (factorial (- n 1))))     ; this recursion is from the if statement and it is also the return statement

  )
(print (factorial 5))

(defun printFact (n)
  (print (factorial n)))

; it depends if you want to make the thing print you can make a function that prints it immediately instead of typing the print statement every time

(defun addition (a b)

  (print (+ a b)))

(defun equation (coefficient power x shift)    ; this is a straight line
  (absolutevalue (+ (* coefficient (powers x power)) (* x shift))))   ; since moving x to the left adds the x and 

(defun absoluteValue (x)
  (if (> x 0) x (- 0 x)))

(defun powers (value power)
  (if (>= 1 power) value
      (* value (powers value (- power 1)))))

(defun integral (coefficient power start end shift)
  (- (equation (/ coefficient (+ power 1)) (+ power 1) end shift) (equation (/ coefficient (+ power 1)) (+ power 1) start shift)))

(defun derivative (coefficient value power)
  (* coefficient power (powers value (- power 1))))

(defun midPoint (coefficient power start end shift)              ; mid point integral

  (if (<= end start) 0

      (+ (midPoint coefficient power (+ start 1) end shift)
         (equation coefficient power (+ start 0.5) shift))       ; finds the mid point

      )
  
                                        ; if the end is equal to the start end the recursion
 
     )  ; this is the change in the equation





; commenting, selection, iteration, data storage, sub routines, referencing, user input, and output, and recursion
;    ;       if statements  loops    idk             methods         idk      needs a compiler  it lets out print    recurses        

