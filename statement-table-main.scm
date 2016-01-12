(define-module (statement-table-main))
(use-modules (ice-9 local-eval))
(use-modules (srfi srfi-1))

(use-modules (gnucash main))
(use-modules (gnucash core-utils))
(use-modules (gnucash gnc-module))
(use-modules (gnucash gettext))
(use-modules (gnucash report eguile-gnc))
(use-modules (gnucash report eguile-utilities))

(gnc:module-load "gnucash/report/report-system" 0)

(define optname-base-account (N_ "Base account"))
(define opthelp-base-account (N_ "Base bank account"))
(define optname-accounts (N_ "Show accounts"))
(define opthelp-accounts
  (N_ "Report on these accounts, if display depth allows. Else, amount is shown in \"Other\"."))
(define optname-depth-limit (N_ "Levels of Subaccounts"))
(define opthelp-depth-limit
  (N_ "Maximum number of levels in the account tree displayed."))
(define optname-from-date (N_ "Start Date"))
(define optname-to-date (N_ "End Date"))
(define optname-stepsize (N_ "Step Size"))

(define (options-generator)
  (let* ((options (gnc:new-options))
         (add-option! (lambda (o)
                        (gnc:register-option options o))))

    ;; Accounts
    (add-option! (gnc:make-account-sel-limited-option
                  gnc:pagename-accounts optname-base-account
                  "a" opthelp-base-account
                  (lambda ()
                    ;; Default getter inspired from the default find-first-account.
                    ;; The default is the most active bank account.
                    (let find-most-active-bank-account
                        ([best-acct '()]
                         [best-split-count 0]
                         [account-list (gnc-account-get-descendants
                                        (gnc-get-current-root-account))])
                      (if (null? account-list)
                          ;; Evaluate to best account.
                          best-acct
                          ;; Try next account.
                          (let* ([acct (car account-list)]
                                 [is-bank-acct (equal?
                                                (xaccAccountGetType acct)
                                                ACCT-TYPE-BANK)]
                                 [split-count (if is-bank-acct
                                                  (length (xaccAccountGetSplitList
                                                           acct))
                                                  -1)]
                                 [this-is-better (> split-count best-split-count)])
                            ;; Tail call with new best account or current best.
                            (find-most-active-bank-account
                             (if this-is-better acct best-acct)
                             (if this-is-better split-count best-split-count)
                             (cdr account-list))))))
                  #f
                  (list ACCT-TYPE-BANK)))
    ;; (add-option! (gnc:make-account-list-option
    ;;               gnc:pagename-accounts optname-accounts
    ;;               "b" opthelp-accounts
    ;;               (lambda ()
    ;;                 (gnc-account-get-descendants-sorted
    ;;                  (gnc-get-current-root-account)))
    ;;               #f #t))
    ;; (gnc:options-add-account-levels!
    ;;  options gnc:pagename-accounts optname-depth-limit
    ;;  "c" opthelp-depth-limit 'all)

    ;; General
    (gnc:options-add-date-interval!
     options gnc:pagename-general
     optname-from-date optname-to-date "a")
    (gnc:options-add-interval-choice!
     options gnc:pagename-general
     optname-stepsize "b"
     'MonthDelta)
    
    options))

(define (renderer report-obj)
  (define (get-option section name)
    (gnc:option-value
     (gnc:lookup-option
      (gnc:report-options report-obj) section name)))

  ;; Base variables from options.
  (let ([title (get-option gnc:pagename-general (N_ "Report name"))]
        [base-account (get-option gnc:pagename-accounts optname-base-account)]
        [from-date-tp (gnc:timepair-start-day-time
                       (gnc:date-option-absolute-time
                        (get-option gnc:pagename-general optname-from-date)))]
        [to-date-tp (gnc:timepair-end-day-time
                     (gnc:date-option-absolute-time
                      (get-option gnc:pagename-general optname-to-date)))]
        [interval (get-option gnc:pagename-general optname-stepsize)]
        [use-links #t]
        [use-js #t])
    ;; Generated variables.
    (let* ([base-account-guid (gncAccountGetGUID base-account)]
           ;; The list of accounts. Equiety and the base-account plus account
           ;; types I have no idea how to handle correctly are excluded.
           [accounts (filter (lambda (a)
                               (not (or (null? a)
                                        (member (xaccAccountGetType a)
                                                (list ACCT-TYPE-EQUITY
                                                      ACCT-TYPE-TRADING
                                                      ACCT-TYPE-NONE))
                                        (equal? (gncAccountGetGUID a)
                                                base-account-guid))))
                             (gnc-account-get-descendants-sorted
                              (gnc-get-current-root-account)))]
           ;; The list of periods.
           [dates-list (gnc:make-date-interval-list
                        (gnc:timepair-start-day-time from-date-tp)
                        (gnc:timepair-end-day-time to-date-tp)
                        (gnc:deltasym-to-delta interval))])
      
      ;; Define functions (some only used once but not lambdas for readability).

      ;; Make a list with the first value being true with the same length
      ;; as the argument. Use for detecting first element while mapping
      ;; without using state (circular lists cannot be used with for-each).
      (define (make-is-first-list ls)
        (cons #t (make-list (- (length ls) 1) #f)))

      (define (reverse-account-values? acct)
        (eqv? (xaccAccountGetType acct) ACCT-TYPE-INCOME))

      (define (account-get-category acct)
        ;; Get the account type category. Because xaccAccountGetType
        ;; returns a number, not a symbol, we return a symbol to be
        ;; able to use the result in case expressions.
        (let ([type (xaccAccountGetType acct)])
          (cond
           [(eqv? type ACCT-TYPE-EXPENSE) 'expense]
           [(eqv? type ACCT-TYPE-INCOME) 'income]
           [(member type (list ACCT-TYPE-ASSET
                               ACCT-TYPE-BANK
                               ACCT-TYPE-CASH
                               ACCT-TYPE-STOCK
                               ACCT-TYPE-MUTUAL
                               ACCT-TYPE-RECEIVABLE
                               ACCT-TYPE-CURRENCY))
            'asset]
           [(member type (list ACCT-TYPE-LIABILITY
                               ACCT-TYPE-CREDIT
                               ACCT-TYPE-PAYABLE))
            'liability]
           ;; Equiety is not a type we should meet here and I don't know
           ;; how to handle the other types.
           [else (error (xaccAccountGetName acct) "not a handled type")])))

      (define (split-get-corr-acct-guid split)
        ;; Why is the only an internal get_corr_account_split() in Split.c?
        ;; We will not rely on xaccGetCorrAccountFullName.
        ;; The algorithm (directly based on get_corr_account_split()) compares
        ;; the sign of the values of each split. The split with another sign
        ;; is the corresponding account, unless there's more than once, in which
        ;; case it's a split transaction.
        ;; Returns 0 for no guid.
        (let* ([val (xaccSplitGetValue split)]
               [val-pos (gnc-numeric-positive-p val)]
               [parent-trans (xaccSplitGetParent split)]
               [sibling-splits (xaccTransGetSplitList parent-trans)])
          (let f ([splits sibling-splits]
                  [guid 0])
            (if (null? splits)
                guid
                (let* ([cur-split (car splits)]
                       [cur-val (xaccSplitGetValue cur-split)]
                       [cur-val-pos (gnc-numeric-positive-p cur-val)])
                  ;; To keep things simple we don't check if cur-split is the
                  ;; same as split. The sign test will do the job.
                  ;; Also we don't do the xaccTransStillHasSplit test. The
                  ;; data is not subject to change while generating a report.
                  (if (not (equal? val-pos cur-val-pos))
                      (if (equal? 0 guid)
                          (f (cdr splits)
                             (gncAccountGetGUID
                              (xaccSplitGetAccount cur-split)))
                          ;; There's already found a corresponding split.
                          ;; This is a split transaction.
                          0)
                      (f (cdr splits) guid)))))))
      
      (define (get-account-periods-splits-data acct)
        ;; TODO: Document
        ;; For each period, create a period splits data object.
        ;; TODO: It would be better to collect these while calculating totals
        ;; because we could then determine has-trans? for placeholders.
        ;; A period data object is a function taking the following arguments:
        ;; - has-trans?: #f if there's no transactions at all (unused account)
        ;; - get-periods: Evaluates to the split lists.
        (let f ((dates-ls (reverse dates-list))
                (has-trans #f)
                (ls '()))
          (if (null? dates-ls)
              ;; Terminator.
              ;; Return "object" with two methods: A shortcut to asking if the
              ;; account has any transactions and a getter for the periods.
              (lambda (m)
                (case m
                  [(has-trans?) has-trans]
                  [(get-periods) ls]
                  [else (error "Invalid method!")]))
              ;; Get splits for the period, generate data and proceed to the next
              ;; period using tail recursion.
              ;; First, construct the query.
              (let ((period (car dates-ls))
                    (book (gnc-get-current-book))
                    (query (qof-query-create-for-splits)))
                (qof-query-set-book query book)
                (gnc:query-set-match-non-voids-only! query book)
                (qof-query-set-sort-order query
                                          (list SPLIT-TRANS TRANS-DATE-POSTED)
                                          (list SPLIT-TRANS TRANS-NUM)
                                          '())
                ;; The comment in Query.h indicates the that the qof_*
                ;; are the new API and the xaccQuery* are the old. However,
                ;; the "new" lacks the convenience functions. The whole
                ;; query should be rewritten when GnuCash gets a SQL API
                ;; anyway.
                (xaccQueryAddAccountMatch query
                                          (list acct)
                                          ;; MATCH-ALL will make the query
                                          ;; return the other split as well.
                                          QOF-GUID-MATCH-ANY
                                          QOF-QUERY-AND)
                (xaccQueryAddDateMatchTS query
                                         #t (car period)
                                         #t (cadr period)
                                         QOF-QUERY-AND)
                ;; Run the query.
                (let ([splits (filter (lambda (s)
                                        (equal? base-account-guid
                                                (split-get-corr-acct-guid s)))
                                   (qof-query-run query))])
                  (qof-query-destroy query)
                  ;; Next period.
                  (f (cdr dates-ls)
                     (or has-trans (not (null? splits)))
                     (cons splits ls)))))))

      ;; Add numbers using settings that maintains an accurate result.
      ;; (cf. GnuCash wiki).
      (define (numeric-add v1 v2)
        ;; TODO: replace with currency aware wrapper
        (gnc-numeric-add v1 v2
                         GNC-DENOM-AUTO
                         (+ GNC-DENOM-REDUCE GNC-RND-NEVER)))

      (define (numeric-div v1 v2)
        ;; Cf. numeric-add.
        (gnc-numeric-div v1 v2
                         GNC-DENOM-AUTO
                         (+ GNC-DENOM-REDUCE GNC-RND-NEVER)))

      ;; Construct an object with data for totals.
      ;; Helper function.
      (define (construct-totals-data-obj value mixed-sign)
        (lambda (m)
          (case m
            ((get-value) value)
            ((mixed-sign?) mixed-sign)
            (else (error "Invalid method!")))))

      ;; For each period, calculate totals based on the splits.
      ;; Helper function for get-accounts-periods-total-data.
      ;; TODO: do not require account,
      (define (splits-totals-data acct periods-splits)
        ;; For each period, get totals.
        (let periods-f ((periods-splits-ls periods-splits)
                        (periods-totals '()))
          (if (null? periods-splits-ls)
              ;; Terminator.
              periods-totals
              (let ((tot-dat
                     ;; Add upp the amounts and build a period data object.
                     ;; I'm not fond of the commodity-collector from
                     ;; report-utilities.scm because of its non-functional nature.
                     (let splits-f ((splits (car periods-splits-ls))
                                    (value (gnc-numeric-zero))
                                    (mixed-sign #f))
                       (if (null? splits)
                           ;; Terminate.
                           ;; Evaluate to the period data "object".
                           (construct-totals-data-obj value mixed-sign)
                           ;; TODO: currency (commodity):
                           ;; transaction.scm (split-value ...
                           ;; or cash-flow to-report-currency
                           (let ((v (xaccSplitGetValue (car splits))))
                             ;; Add the next split using tail recursion.
                             (splits-f (cdr splits)
                                       (numeric-add value v)
                                       (or mixed-sign))))))) ; TODO
                (periods-f (cdr periods-splits-ls)
                           (append periods-totals (list tot-dat)))))))

      ;; For for each period, calculate totals using the totals already
      ;; calculated for child accounts.
      ;; TODO: do not require account,
      (define (placeholder-totals-data acct acct-depths totals-below)
        (let ((this-depth (gnc-account-get-current-depth acct)))
          (map (lambda (period-i)
                 (let totals-f ([a-depths acct-depths]
                                [tot-ls totals-below]
                                [value (gnc-numeric-zero)])
                   (if (or (null? tot-ls)
                           (<= (car a-depths) this-depth))
                       (construct-totals-data-obj value #f)
                       (let ([tot (list-ref (car tot-ls) period-i)]
                             [depth (car a-depths)])
                         ;; We could use gnc-account-get-parent and compare guid,
                         ;; but the depth method lets us terminate when we reach
                         ;; an account on the same level.
                         (totals-f (cdr a-depths)
                                   (cdr tot-ls)
                                   (if (> depth (+ 1 this-depth))
                                       value
                                       (numeric-add value
                                                    (tot 'get-value))))))))
               (iota (length dates-list)))))

      ;; Calculate totals. For each account (bottom up): If it's not a
      ;; placeholder account, for each period: add up splits. If it's a
      ;; placeholder account, for each period: add up totals calculated
      ;; in child accounts.
      ;; A totals-data object is made by (construct-totals-data-obj)
      (define (get-accounts-periods-total-data periods-splits-data)
        ;; For each account, get totals for periods.
        (let accounts-f ([accounts-ls (reverse accounts)]
                         [periods-splits-data-ls (reverse periods-splits-data)]
                         [acct-depths '()]
                         [totals '()])
          (if (null? accounts-ls)
              ;; Terminator.
              totals
              ;; For each period, calculate totals.
              (let ([acct (car accounts-ls)]
                    [periods-splits ((car periods-splits-data-ls) 'get-periods)])
                ;; TODO: fail or implement if an account has subaccounts but is
                ;; not a placeholder.
                (let ([acct-totals
                       (if (xaccAccountGetPlaceholder acct)
                           (placeholder-totals-data acct
                                                    acct-depths
                                                    totals)
                           ;; The account is not a placeholder.
                           ;; Calculate the total value based on
                           ;; splits.
                           (splits-totals-data acct
                                               periods-splits))])
                  (accounts-f (cdr accounts-ls)
                              (cdr periods-splits-data-ls)
                              (cons (gnc-account-get-current-depth acct) acct-depths)
                              ;; The account row is added to the beginning of the
                              ;; list. This is the order of the table and the way
                              ;; we want it when adding up sub-accounts.
                              (cons acct-totals totals)))))))

      (define (get-account-total periods-total-data)
        (fold (lambda (tot-dat total)
                (numeric-add total
                             (tot-dat 'get-value)))
              (gnc-numeric-zero)
              periods-total-data))

      (define (whole-period-average total)
        (numeric-div total
                     (gnc-numeric-create (length dates-list) 1)))

      (define (get-periods-totals accts-periods-total-data)
        ;; Get three lists with a total for each period and a sum.
        ;; Totals are three values:
        ;; - total (where did all money from the account go)
        ;; - total without assets (savings are not really expenses)
        ;; - total without assets and liabilities (i.e. stuff that
        ;;   raises equiety not counted as expense)
        (let* ([periods-totals
                (fold
                 (lambda (period-i per-tots)
                   (let ([totals
                          (fold
                           (lambda (periods-tot-dat acct tots)
                             (if (xaccAccountGetPlaceholder acct)
                                 tots
                                 (let* ([a-tot ((list-ref
                                                 periods-tot-dat
                                                 period-i) 'get-value)]
                                        [a-cat (account-get-category acct)])
                                   (gnc:debug (xaccAccountGetName acct)
                                              " "
                                              a-cat)
                                   (case a-cat
                                     [(asset)
                                      (list (numeric-add (car tots) a-tot)
                                            (cadr tots)
                                            (caddr tots))]
                                     [(liability)
                                      (list (numeric-add (car tots) a-tot)
                                            (numeric-add (cadr tots) a-tot)
                                            (caddr tots))]
                                     [else
                                      (list (numeric-add (car tots) a-tot)
                                            (numeric-add (cadr tots) a-tot)
                                            (numeric-add (caddr tots) a-tot))]))))
                           (make-list 3 (gnc-numeric-zero))
                           accts-periods-total-data
                           accounts)])
                     ;; Append the totals of the period to the three lists.
                     (list
                      (append (car per-tots)
                              (list (car totals)))
                      (append (cadr per-tots)
                              (list (cadr totals)))
                      (append (caddr per-tots)
                              (list (caddr totals))))))
                 (make-list 3 '())
                 (iota (length dates-list)))]
               ;; The total of all periods.
               [all-totals (map (lambda (tot-ls)
                                  (reduce numeric-add
                                          (gnc-numeric-zero)
                                          tot-ls))
                                periods-totals)]
               [averages (map (lambda (tot)
                                (whole-period-average tot))
                              all-totals)])
          ;; Create the final lists.
          (let ([total
                 (append (car periods-totals)
                         (list (car averages))
                         (list (car all-totals)))]
                [total-min-asset
                 (append (cadr periods-totals)
                         (list (cadr averages))
                         (list (cadr all-totals)))]
                [total-min-asset-liab
                 (append (caddr periods-totals)
                         (list (caddr averages))
                         (list (caddr all-totals)))])
            ;; Return an "object" instead of a list.
            (lambda (m)
              (case m
                [(total) total]
                [(total-min-asset) total-min-asset]
                [(total-min-asset-liab) total-min-asset-liab]
                [else (error "Invalid method!")])))))

      ;; let-account-data* defines a shortcut to a let with with the many
      ;; maps of the account variable. The << is just for fun or to clarify
      ;; that the variable is not defined to be the function but is generated
      ;; by the function.
      ;; This was no longer a great idea after most of the account data was
      ;; moved to the acct-row building.
      (let-syntax
          ((let*-account-data
            (lambda (x)
              (syntax-case x ()
                ((_ (<binding*> ...) <e> <e*> ...)
                 (with-syntax (((<var-bind*> ...)
                                (map
                                 (lambda (y)
                                   (syntax-case y (<< :)
                                     ;; Normal let
                                     ((<v> <b>)
                                      #'(<v> <b>))
                                     ;; Map accounts
                                     ((<v> << <f>)
                                      #'(<v> (map <f> accounts)))
                                     ;; Map another list than accounts
                                     ((<v> << <f> : <ls>)
                                      #'(<v> (map <f> <ls>)))))
                                 #'(<binding*> ...))))
                              #'(let* (<var-bind*> ...) <e> <e*> ...)))))))
        ;; Model variables used by the template.
        (let*-account-data
         ([accounts-periods-splits-data << get-account-periods-splits-data]
          [accounts-periods-total-data (get-accounts-periods-total-data
                                        accounts-periods-splits-data)]
          [accounts-total << get-account-total : accounts-periods-total-data]
          [accounts-average << whole-period-average : accounts-total]
          [periods-totals (get-periods-totals accounts-periods-total-data)])
         ;; Ready to render ... or no, local-eval does not support
         ;; macros (cf. comment on analyze-identifiers in ice9/local-eval.scm).
         ;; The for loop from eguile-utilities has very poor readability when
         ;; iterating a lot of lists simultaniously. We want another version with
         ;; each value and list defined together (like let).
         ;; But using our for-in in template results in "unsupported binding"
         ;; error. Instead, do some more preparation for the rendering.
         ;; For the same reason we cannot use records.
         (let-syntax ([filter-map-for-in
                       (syntax-rules ()
                         [(_ ((<var> <ls>)
                              (<var*> <ls*>) ...)
                             <e> <e*> ...)
                          ;; Use for-each if this is to be a "for-in".
                          (filter-map (lambda (<var> <var*> ...)
                                 <e> <e*> ...)
                               <ls> <ls*> ...)])])
           (define (html-escape-string str)
             (list->string (fold (lambda (c ls)
                                   (let ([x (case c
                                              [(#\<) "&lt;"]
                                              [(#\>) "&gt;"]
                                              [(#\") "&quot;"]
                                              [(#\&) "&amp"]
                                              [else (string c)])])
                                     (append ls (string->list x))))
                                 '()
                                 (string->list str))))
           
           ;; Build rows.
           (let* ([acct-rows
                   (filter-map-for-in
                    ([acct accounts]
                     [periods-splits-data accounts-periods-splits-data]
                     [periods-total-data accounts-periods-total-data]
                     [average accounts-average]
                     [total accounts-total])
                    ;; Filter out rows that should not be rendered. We want
                    ;; as little as possible in the unreadable eguile.
                    (let ([placeholder? (xaccAccountGetPlaceholder acct)])
                      (and (or placeholder?
                               (periods-splits-data 'has-trans?))
                           (lambda (m)
                             (case m
                               [(account)
                                acct]
                               [(name-format)
                                (let ([name-str (html-escape-string
                                                 (xaccAccountGetName acct))])
                                  (if (and use-links
                                           (not placeholder?))
                                      (string-append
                                       "<a href=\"gnc-register:acct-guid="
                                       (gncAccountGetGUID acct)
                                       "\">"
                                       name-str
                                       "</a>")
                                      name-str))]
                               [(category-string)
                                (symbol->string (account-get-category acct))]
                               [(depth)
                                (gnc-account-get-current-depth acct)]
                               [(placeholder?)
                                placeholder?]
                               [(periods-splits)
                                (periods-splits-data 'get-periods)]
                               [(periods-total-data)
                                periods-total-data]
                               [(average)
                                average]
                               [(total)
                                total]
                               [else (error "Invalid method!")])))))]
                  [row-groups
                   (car
                    (let f ([rows acct-rows]
                            [groups '()])
                      (if (null? rows)
                          ;; Done. Return groups and none remaining rows.
                          ;; Due to the non-tail recursion when making a
                          ;; subgroup, this condition may be met multiple
                          ;; times and is not itself a terminator.
                          (cons groups '())
                          (let* ([cur-row (car rows)]
                                 [cur-row-depth (cur-row 'depth)]
                                 [next-row-depth (if (null? (cdr rows))
                                                     0
                                                     ((cadr rows) 'depth))])
                            (cond
                             [(> cur-row-depth next-row-depth)
                              ;; This is the the last row in the group.
                              ;; Return the group and the remaining rows.
                              (cons (append groups (list cur-row))
                                    (cdr rows))]
                             [(= cur-row-depth next-row-depth)
                              ;; The next row is in the same group.
                              (f (cdr rows)
                                 (append groups (list cur-row)))]
                             [else
                              ;; This row begins a new group.
                              ;; Insert a subgroup in the list.
                              (let* ([result (f (cdr rows)
                                                (list cur-row))]
                                     [grp (car result)]
                                     [rows-remain (cdr result)]
                                     [new-groups (append groups (list grp))]
                                     [new-next-row-depth
                                      (if (null? rows-remain)
                                          0
                                          ((car rows-remain) 'depth))])
                                ;; Did the sub-group end this group?
                                ;; Return or continue group.
                                (if (> cur-row-depth new-next-row-depth)
                                    (cons new-groups rows-remain)
                                    (f rows-remain new-groups)))])))))])

             ;; Define rendering functions.

             (define (make-id-list ls)
               ;; Create a list of ids.
               ;; The list will be the length of the given list.
               ;; The ids will be string so that they can be used
               ;; with string-join.
               (map (lambda (n)
                      (number->string (+ 1 n)))
                    (iota (length ls))))

             (define (id-list->class-str id-list)
               ;; Create a string with space-separated id-classes.
               ;; The id-list is deepest level first and the resulting
               ;; string is "acct-grp-id-<a> acct-grp-id-<a>-<b>" and so on.
               (string-join
                (let f ([id-ls id-list]
                        [ls '()])
                  (if (null? id-ls)
                      ls
                      (f (cdr id-ls)
                         (cons (string-append "acct-grp-id-"
                                              (string-join (reverse id-ls)
                                                           "-"))
                               ls))))))

             (define (split-get-formatted-notes-string split)
               (html-escape-string (xaccTransGetNotes
                                    (xaccSplitGetParent split))))
             
             (define (format-split-string split str)
               (if use-links
                   (string-append
                    "<a href=\"gnc-register:split-guid="
                    (gncSplitGetGUID split)
                    "\">"
                    str
                    "</a>")
                   str))

             (define (format-split-date split)
               (format-split-string split
                                    (gnc-print-date
                                     (gnc:secs->timepair
                                      (xaccTransGetDate
                                       (xaccSplitGetParent split))))))
             
             (define (format-split-description split)
               (format-split-string split
                                    (xaccTransGetDescription
                                     (xaccSplitGetParent split))))

             (define (format-split-value split acct)
               (format-split-string split
                                    (format-acct-number
                                     (xaccSplitGetValue split) acct)))
             
             (define (format-date d)
               (gnc-print-date (car d)))

             ;; Format number
             (define (format-number value reverse)
               (let ([val (if reverse
                              (gnc-numeric-neg value)
                              value)])
                 (xaccPrintAmount (gnc-numeric-convert val
                                                       100
                                                       (+ GNC-DENOM-REDUCE
                                                          GNC-RND-ROUND))
                                  (gnc-default-print-info #f))))

             ;; Format number, using account to determine wether to change sign.
             (define (format-acct-number value acct)
               ;; TODO: like transaction.scm, account-types-to-reverse
               (format-number value
                              (reverse-account-values? acct)))

             ;; Render
             (eguile-file-to-string
              (find-file "statement-table.eguile.scm")
              (the-environment)))))))))

(export options-generator)
(export renderer)
