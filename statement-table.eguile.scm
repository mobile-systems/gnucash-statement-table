<?scm
(letrec*
    ([render-acct-row
      (lambda (a-row id-ls is-header)
?>
<tr class="acct-level-<?scm:d (a-row 'depth)
           ?><?scm (if (a-row 'placeholder?) ?> acct-placeholder<?scm )
           ?> acct-cat-<?scm:d (a-row 'category-string)
           ?> <?scm:d (id-list->class-str id-ls)
           ?><?scm (if is-header ?> acct-grp-header<?scm )
           ?>" data-acct-grp-ids="<?scm:d (string-join id-ls) ?>">
  <td class="acct-name">
    <?scm:d (a-row 'name-format) ?>
  </td>
  <?scm (for (total splits) in
             ((a-row 'periods-total-data)
              (a-row 'periods-splits)) do ?>
  <td<?scm (if (and use-js (not (null? splits))) ?> class="has-splits"<?scm ) ?>>
    <span class="total">
      <?scm:d (format-acct-number (total 'get-value) (a-row 'account)) ?>
    </span>
    <?scm (if (and use-js (not (null? splits))) (begin ?>
    <table class="splits hidden">
      <?scm (for split in splits do
              (let* ([trans (xaccSplitGetParent split)]
                     [notes (xaccTransGetNotes trans)]
                     [has-notes (not (equal? notes ""))]) ?>
      <tr<?scm (if has-notes (begin ?> title="<?scm:d
              (html-escape-string notes) ?>"<?scm )) ?>>
        <td class="split-date">
          <?scm:d (gnc-print-date
                    (gnc:secs->timepair
                      (xaccTransGetDate trans))) ?>
        </td>
        <td class="split-description">
          <?scm:d (format-split-description split) ?>
          <?scm (if has-notes (begin ?>
          <span class="split-info-symbol">
            &#x2004;&#x2139;&#x20DD;&#x2004;
          </span>
          <?scm )) ?>
        </td>
        <td class="split-value">
          <?scm:d (format-acct-number (xaccSplitGetValue split)
                                      (a-row 'account)) ?>
        </td>
      </tr>
      <?scm )) ; end (for split in ...
      ?>
    </table>
    <?scm )) ; end (if (not (null? splits)) ...
    ?>
  </td>
  <?scm ) ; end (for (total ...
  ?>
  <td><?scm:d (format-acct-number (a-row 'average) (a-row 'account)) ?></td>
  <td><?scm:d (format-acct-number (a-row 'total) (a-row 'account)) ?></td>
</tr>
<?scm )] ; end [render-row
      [render-group
       (lambda (group id-ls)
         ;; The elements in the list may be an account row or a new group.
         (for (elem is-first grp-id) in (group
                                         (make-is-first-list group)
                                         (make-id-list group)) do
              (if (list? elem)
                  (render-group elem
                                (cons grp-id id-ls))
                  (render-acct-row elem id-ls is-first))))]) ; end let (...

;;; Begin document.
?><!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title><?scm:d title ?></title>
    <link rel="shylesheet" href="<?scm:d (find-file "normalize.css") ?>">
    <link rel="stylesheet" href="<?scm:d (find-file "statement-table.css") ?>">
  </head>
  <body>
    <h1>
      <?scm:d (xaccAccountGetName base-account) ?>
      <?scm:d (gnc-print-date from-date-tp) ?>
      <?scm:d (_ "to") ?>
      <?scm:d (gnc-print-date to-date-tp) ?>
    </h1>
    <table class="main-table">
      <colgroup>
        <col class="col-account-names"/>
        <col class="col-periods" span="<?scm:d (length dates-list) ?>"/>
        <col class="col-average"/>
        <col class="col-total"/>
      </colgroup>
      <thead>
        <tr>
          <th></th>
          <?scm (for d in dates-list do ?>
          <th class="header-date"><?scm:d (format-date d) ?></th>
          <?scm ) ?>
          <th><?scm:d (_ "Average") ?></th>
          <th><?scm:d (_ "Total") ?></th>
        </tr>
      </thead>
      <tbody>
      <?scm
      (for (elem grp-id) in (row-groups
                             (make-id-list row-groups)) do
           (if (list? elem)
               (render-group elem (list grp-id))
               (render-acct-row elem (list grp-id) #f)))
      ?>
      </tbody>
      <tfoot>
        <tr>
          <td><?scm:d (_ "Total") ?></td>
          <?scm (for totals in (periods-totals 'total) do ?>
          <td><?scm:d (format-number totals #t) ?></td>
          <?scm ) ?>
        </tr>
        <tr>
          <td><?scm:d (_ "Total minus assets") ?></td>
          <?scm (for totals in (periods-totals 'total-min-asset) do ?>
          <td><?scm:d (format-number totals #t) ?></td>
          <?scm ) ?>
        </tr>
        <tr>
          <td><?scm:d (_ "Total minus assets and liabilities") ?></td>
          <?scm (for totals in (periods-totals 'total-min-asset-liab) do ?>
          <td><?scm:d (format-number totals #t) ?></td>
          <?scm ) ?>
        </tr>
      </tfoot>
    </table>

    <?scm (if use-js (begin ?>
    <script src="<?scm:d (gnc-path-find-localized-html-file
                          "jqplot/jquery.min.js") ?>"></script>
    <script src="<?scm:d (find-file "statement-table.js") ?>"></script>
    <?scm )) ?>
  </body>
</html>
<?scm ) ?>
