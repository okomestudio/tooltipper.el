;;; tooltipper.el --- Tooltipper minor mode  -*- lexical-binding: t -*-
;;
;; Copyright (C) 2025 Taro Sato
;;
;; Author: Taro Sato <okomestudio@gmail.com>
;; URL: https://github.com/okomestudio/tooltipper.el
;; Version: 0.1.2
;; Keywords: help tools
;; Package-Requires: ((emacs "29.1"))
;;
;;; License:
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;;
;;; Commentary:
;;
;; A minor mode to activate tooltips without mouse cursor.
;;
;;; Code:

(require 'timer)
(require 'tooltip)

(defgroup tooltipper nil
  "Customization group for the `tooltipper' package."
  :group 'help
  :group 'tools
  :version "0.1.1"
  :tag "Tool Tips")

(defcustom tooltipper-delay 0.7
  "Seconds to wait before displaying a tooltip for the first time."
  :type 'number
  :group 'tooltipper)

(defun tooltipper-inspect-invisibles ()
  "Get the position of an at-point element.
Some elements like Org link may have tooltip texts embedded in hidden
parts. This function inspects such element to obtain the point of
interest."
  ;; Get to the path in an Org link in case it is invisible.
  (and (derived-mode-p 'org-mode)
       (org-in-regexp org-link-any-re)
       (when-let* ((text (match-string 0))
                   (start (match-beginning 0))
                   (key-start (string-match ":" text)))
         (+ 1 start key-start))))

(defun tooltipper-display-at-point ()
  "Display a tooltip for the text at point, if available."
  (interactive)
  (when-let*
      ((point (point))
       (tooltip-point (or (tooltipper-inspect-invisibles)
                          point))
       (tooltip-text (and (not (minibufferp))
                          (bound-and-true-p tooltip-mode)
                          (get-text-property tooltip-point 'help-echo)))
       (x-max-tooltip-size '(80 . 25))
       (tooltip-frame-parameters tooltip-frame-parameters)
       (window (selected-window))
       (x-y (posn-x-y (posn-at-point point window)))
       (window-x (car x-y))
       (window-y (cdr x-y))
       (frame (window-frame window))
       (frame-left (frame-parameter frame 'left))
       (frame-left (if (consp frame-left) (car frame-left) frame-left))
       (frame-top (frame-parameter frame 'top))
       (frame-top (if (consp frame-top) (car frame-top) frame-top))
       (window-origin (window-pixel-edges window))
       (window-left (nth 0 window-origin))
       (window-top (nth 1 window-origin))
       (text (if (stringp tooltip-text)
                 tooltip-text
               (funcall tooltip-text window nil tooltip-point)))
       (space-width (string-pixel-width " "))
       (dx (min (length (substring-no-properties text))
                (car x-max-tooltip-size)))
       (left (+ window-x window-left frame-left
                (* space-width
                   (if (> window-x (/ (window-width window t) 2))
                       (* -1 (1- dx))
                     1))))
       (top (+ window-y window-top frame-top (* space-width 6))))
    (add-to-list 'tooltip-frame-parameters `(left . ,left))
    (add-to-list 'tooltip-frame-parameters `(top . ,top))
    (tooltip-show text)))

(defvar tooltipper--timer nil
  "Timer for displaying tooltips at point.")

(defun tooltipper--start-timer ()
  "Start a timer to display tooltips after a delay."
  (when tooltipper--timer
    (cancel-timer tooltipper--timer))
  (setq tooltipper--timer
        (run-with-idle-timer tooltipper-delay nil
                             #'tooltipper-display-at-point)))

;;;###autoload
(define-minor-mode tooltipper-mode
  "Toggle tooltipper mode.
When this global minor mode is enabled, Emacs displays help text in a
tooltip window. Unlike `tooltip-mode', this mode does not trigger
a tooltip with mouse cursor; it triggers on the window cursor."
  :global t
  :init-value nil
  :lighter "tooltipper"
  (pcase (and tooltipper-mode (fboundp 'x-show-tip))
    ('t (add-hook 'post-command-hook #'tooltipper--start-timer))
    (_ (remove-hook 'post-command-hook #'tooltipper--start-timer))))

(provide 'tooltipper)
;;; tooltipper.el ends here
