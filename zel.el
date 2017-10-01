;;; zel.el --- Access frecent files easily  -*- lexical-binding: t; -*-

;; Copyright (C) 2017 Free Software Foundation, Inc.

;; Author: Sebastian Christ <rudolfo.christ@gmail.com>
;; URL: tbd
;; Version: 0.1.0-pre
;; Package-Requires: ((emacs "25") cl-lib subr-x frecency)
;; Keywords: convenience, files, matching

;;; Commentary:

;; tbd

;;;; Installation

;;;;; MELPA

;; If you installed from MELPA, you're done.

;;;;; use-package

;; tbd.

;;;;; Manual

;; Install these required packages:

;; - tbd

;; Then put this file in your load-path, and put this in your init
;; file:

;; (require 'zel)

;;;; Usage

;;;; Credits

;; - https://github.com/rupa/z

;;; License

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

;;;; Requirements

(require 'cl-lib)
(require 'subr-x)
(require 'frecency)

;;;; Variables

(defgroup zel ()
  "Access frecent files easily."
  :group 'convenience
  :group 'files
  :group 'matching)


(defcustom zel-history-file "~/.emacs.d/zel-history"
  "File where the history is saved."
  :type 'file)


(defcustom zel-exclude-patterns '(".*/\.#.*" "\.git/COMMIT_EDITMSG")
  "List of regexps to exclude files.

Each file-name that matches one of this patterns is not added to
the frecent list."
  :type '(repeat regexp))


(defvar zel--aging-threshold 9000
  "Threshold used to clean out old items.

When the sum of all entries reach this threshold older items are
removed.")


(defvar zel--aging-multiplier 0.99
  "Multiplier used on each item do determine the age of it.

If the age of an item after applying the multiplier is less than
1 it's determined to be too old and gets removed.")


(defvar zel--frecent-list nil
  "The list with the frecent items.")


;;;; Functions

(defun zel--file-excluded-p (filename)
  "Evaluate to t if the file with FILENAME should be excluded.

FILENAME has to be absolute."
  (cl-some (lambda (pattern)
             (string-match-p pattern filename))
           zel-exclude-patterns))

(defun zel--entry-score (entry)
  "Return score for ENTRY."
  (frecency-score (cadr entry)))


(defun zel--update-frecent-list ()
  "Update the frecent list.

This updates the score for current buffer's file or if it doesn't
exist adds it to the frecent list."
  ;; ignore buffers without file
  (when-let ((file-name (buffer-file-name)))
    (unless (zel--file-excluded-p file-name)
      (if-let ((entry (assoc file-name zel--frecent-list)))
          (setf (cadr entry)
                (frecency-update (cadr entry)))
        (push (list file-name (frecency-update '()))
              zel--frecent-list))
      ;; sort frecent files
      (setq zel--frecent-list
            (cl-sort zel--frecent-list #'> :key #'zel--entry-score)))))

(defun zel--frecent-file-paths ()
  "List frecent file paths in descending order by their rank."
  (mapcar #'first zel--frecent-list))


(defun zel--frecent-file-paths-with-score ()
  "List all frecent file paths with their scrore."
  (mapcar (lambda (entry)
            (cons (car entry)
                  (zel--entry-score entry)))
          zel--frecent-list))


;;;;; Commands

(cl-defmacro zel--with-history-buffer (&body body)
  (declare (indent defun))
  (let ((buffer (cl-gensym "buffer")))
    `(let ((,buffer (find-file-noselect (expand-file-name zel-history-file) t)))
       (with-current-buffer ,buffer
         ,@body))))


(defun zel-write-history ()
  "Writes the current frecent list to the `zel-history-file'."
  (interactive)
  (zel--with-history-buffer
    (erase-buffer)
    (goto-char (point-min))
    (print zel--frecent-list (current-buffer))
    (save-buffer)))


(defun zel-load-history ()
  "Load the history file found under `zel-history-file'."
  (interactive)
  (zel--with-history-buffer
    (goto-char (point-min))
    (setq zel--frecent-list (read (current-buffer)))))


(defun zel-diplay-rankings ()
  "Shows the current ranking of files."
  (interactive)
  (let ((items (zel--frecent-file-paths-with-score)))
    (with-output-to-temp-buffer "*zel-frecent-rankings*"
      (set-buffer "*zel-frecent-rankings*")
      (erase-buffer)
      (dolist (item items)
        (insert (format "\n% 4d -- %s"
                        (cdr item)
                        (first item)))))))


(defun zel-reset-frecent-list (&optional write-history-p)
  "Empties the frecent list.

If WRITE-HISTORY-P is non-nil (or `zel-reset-frecent-list' is
called with a prefix argument) the history files is saved as
well."
  (interactive "P")
  (setq zel--frecent-list nil)
  (when write-history-p
    (zel-write-history)))


;;;###autoload
(defun zel-install ()
  "Install `zel'.

Registers `zel' on the following hooks:

- `find-file-hook': to update the frecent list.
- `kill-emacs-hook': write the frecent list to the `zel-history-file'."
  (interactive)
  (unless (file-exists-p (expand-file-name zel-history-file))
    (zel-write-history))
  (zel-load-history)
  (add-hook 'find-file-hook #'zel--update-frecent-list)
  (add-hook 'kill-emacs-hook #'zel-write-history))


;;;###autoload
(defun zel-uninstall ()
  "Deregisters hooks."
  (interactive)
  (zel-write-history)
  (setq zel--frecent-list nil)
  (remove-hook 'find-file-hook #'zel--update-frecent-list)
  (remove-hook 'kill-emacs-hook #'zel-write-history))

;;;; Footer

(provide 'zel)

;;; zel.el ends here
