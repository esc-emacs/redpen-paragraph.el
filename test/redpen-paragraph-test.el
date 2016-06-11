;;; redpen-paragraph-test.el --- test for redpen-paragraph

;;; Commentary:
;; test for redpen-paragraph by ert

(require 'ert)
(require 'redpen-paragraph)

;;; Code:
(ert-deftest detect-english ()
  "Detect english."
  (should (redpen-paragraph-is-english ""))
  (should (redpen-paragraph-is-english "abc"))
  (should (redpen-paragraph-is-english "abcdあいう")))

(ert-deftest detect-not-english ()
  "Detect the other language."
  (should-not (redpen-paragraph-is-english "あいう"))
  (should-not (redpen-paragraph-is-english "abcあいう"))
  (should-not (redpen-paragraph-is-english "abcあいうえ")))

(ert-deftest target-filename ()
  "Return target filename."
  (should (eq redpen-target-filename (redpen-target-filename))))

(ert-deftest read-the-process-stdout-as-json ()
  "Read the process stdout as JSON."
  (with-temp-buffer
    (let ((redpen-paragraph-compilation-buffer-name (buffer-name))
          (proc
           (progn
             (async-shell-command
              (concat "echo "
                      (shell-quote-argument
                       (json-encode '((errors . [])))))
              (current-buffer))
             (get-buffer-process (current-buffer))))
          (desc "dummy"))
      (sleep-for 1) ;; wait until exit of echo process.
      (redpen-paragraph-sentinel proc desc)))
  (should (equal "" (buffer-string))))

(ert-deftest read-the-process-stdout-as-not-json ()
  "Read the process stdout as not JSON."
  (with-temp-buffer
    (let ((redpen-paragraph-compilation-buffer-name (buffer-name))
          (proc
           (progn
             (async-shell-command
              "echo test"
              (current-buffer))
             (get-buffer-process (current-buffer))))
          (desc "dummy"))
      (sleep-for 1) ;; wait until exit of echo process.
      (should-error
       (redpen-paragraph-sentinel proc desc)
       :type 'json-unknown-keyword))))

(ert-deftest invoke-redpen-paragraph ()
  "Invoke redpen-paragraph."
  (with-temp-buffer
    (let ((redpen-paragraph-compilation-buffer-name (current-buffer))
          (redpen-commands
           `(,(concat
               "echo "
               (shell-quote-argument
                (json-encode '((errors . []))))))))
      (redpen-paragraph)
      (sleep-for 1) ;; wait until exit of echo process.
      (with-current-buffer redpen-paragraph-compilation-buffer-name
        (should (equal "" (buffer-string)))
        (should (eq major-mode 'compilation-mode))))))

(ert-deftest list-errors-by-required-parameters ()
  "List the all parameter error."
  (let* ((redpen-server-response
          '(:errors
            [(:sentence
              "Sentence"
              :errors
              [(:validator
                "Validator"
                :message
                "Message"
                :position
                (:start
                 (:line 0 :offset 1)
                 :end
                 (:line 3 :offset 4)))])]))
         (redpen-cli-response (make-vector 1 redpen-server-response))
         (expected-buffer-string
          (concat
           "Validator at start 1.2, end 3.4: Message\n"
           "Sentence\n" "\n")))
    (with-temp-buffer
      (let ((redpen-paragraph-compilation-buffer-name (buffer-name)))
        (redpen-paragraph-list-errors redpen-server-response)
        (should (equal expected-buffer-string (buffer-string)))))
    (with-temp-buffer
      (let ((redpen-paragraph-compilation-buffer-name (buffer-name)))
        (redpen-paragraph-list-errors redpen-cli-response)
        (should (equal expected-buffer-string (buffer-string)))))))

(ert-deftest check-cursor-position ()
  "Check cursor position to paragraph."
  (with-temp-buffer
    (insert "test1\n\ntest2\n\ntest3")
    (let ((redpen-commands
           `(,(concat
               "echo "
               (shell-quote-argument
                (json-encode '((errors . [])))))))
          ;; lineNum position-on-the-line expected-result
          (tests '((1 nil "test1\n") (1 'end "test1\n")
                   (2 nil "\ntest2\n")
                   (3 nil "\ntest2\n") (3 'end "\ntest2\n")
                   (4 nil "\ntest3")
                   (5 nil "\ntest3") (5 'end "\ntest3"))))
      (mapc
       (lambda (test)
         (cl-destructuring-bind (lineNum position expected) test
           (goto-char (point-min))
           (if (> lineNum 1) (forward-line (1- lineNum)))
           (if (eq position 'end) (move-end-of-line 1))
           (redpen-paragraph)
           (sleep-for 1) ;; wait until exit of echo process.
           (with-current-buffer
               (find-file-noselect redpen-temporary-filename)
             (should (equal expected (buffer-string))))
           (kill-buffer
            (find-file-noselect redpen-temporary-filename))))
       tests)

      (mark-whole-buffer)
      ;; for (use-region-p) on emacs --batch
      (let ((transient-mark-mode t))
        (redpen-paragraph))
      (sleep-for 1) ;; wait until exit of echo process.
      (with-current-buffer
          (find-file-noselect redpen-temporary-filename)
        (should
         (equal "test1\n\ntest2\n\ntest3" (buffer-string)))))))

;; Local Variables:
;; coding: utf-8
;; End:

;;; redpen-paragraph-test.el ends here
