(define-module (statement-table))
(use-modules (gnucash gnc-module))
(use-modules (gnucash gettext))

(gnc:module-load "gnucash/report/report-system" 0)

(use-modules (statement-table-main))

(define (reload-report-module)
  (reload-module (resolve-module '(statement-table-main))))

(gnc:define-report
 'version 1
 'name (N_ "Statement table")
 'report-guid "8d4139ebc873440ebc7a97a6fc842a05"
 'menu-path (list gnc:menuname-utility)
 'options-generator (lambda ()
                      (reload-report-module)
                      (options-generator))
 'renderer (lambda (report-obj)
             (reload-report-module)
             (renderer report-obj)))
