sap.ui.define(
  [
    "sap/ui/core/UIComponent",
    "sap/m/library",
    "sap/m/MessageBox",
    "sap/m/MessageToast",
    "bpc/notebook/model/Api",
  ],
  function (UIComponent, library, MessageBox, MessageToast, Api) {
    "use strict";
    var m = sap.m;
    function displayTime(value) {
      var stamp = String(value || "").replace(",", ".").replace(/(\.\d{3})\d+/, "$1");
      var date = new Date(stamp);
      return isNaN(date.getTime()) ? value : date.toLocaleString(undefined, {
        month: "short", day: "numeric", hour: "2-digit", minute: "2-digit"
      });
    }
    return UIComponent.extend("bpc.notebook.Component", {
      metadata: { manifest: "json" },
      createContent: function () {
        var self = this;
        this.selected = null;
        this.dirty = false;
        this.runId = null;
        this.pageOffset = 0;
        this.list = new m.List({
          mode: "SingleSelectMaster",
          selectionChange: function (e) {
            var item = e.getParameter("listItem");
            self.open(item.data("id"));
          },
        }).addStyleClass("notebookList");
        this.sidebar = new m.VBox({
          width: "336px",
          items: [
            new m.Title({ text: "WORKSPACE", level: "H5" }),
            new m.Text({ text: "My notebooks" }).addStyleClass("sideTitle"),
            new m.Button({
              text: "New notebook",
              icon: "sap-icon://add",
              width: "100%",
              press: function () {
                self.create(false);
              },
            }).addStyleClass("newNotebookButton"),
            new m.Button({
              text: "Open allocation demo",
              icon: "sap-icon://activity-items",
              width: "100%",
              press: function () {
                self.create(true);
              },
            }),
            this.list,
            new m.Text({ text: "Saved source is versioned. Each run keeps its own snapshot." }).addStyleClass(
              "sideNote",
            ),
          ],
        }).addStyleClass("sidebar");
        this.title = new m.Title({ text: "Your next calculation starts here", level: "H1" }).addStyleClass("notebookTitle");
        this.meta = new m.Text({ text: "A workspace for ideas, calculations, and results you can trust." }).addStyleClass("notebookMeta");
        this.inputs = new m.HBox({ wrap: "Wrap" }).addStyleClass("inputs");
        this.cells = new m.VBox().addStyleClass("cells");
        this.runList = new m.Select({
          width: "100%",
          change: function (e) {
            self.inspect(e.getSource().getSelectedKey());
          },
        });
        this.runStatus = new m.ObjectStatus({ text: "No executions yet" }).addStyleClass("runStatus");
        this.runDetails = new m.Text().addStyleClass("runDetails");
        this.runMessages = new m.VBox();
        this.outputSelect = new m.Select({
          change: function () {
            self.pageOffset = 0;
            self.tableName = "";
            self.preview();
          },
        });
        this.datasetSelect = new m.Select({ visible: false, change: function(e) {
          self.tableName = e.getSource().getSelectedKey(); self.pageOffset = 0; self.preview();
        }});
        this.table = new m.Table({
          columns: [
            new m.Column({ header: new m.Label({ text: "Cost centre" }) }),
            new m.Column({ header: new m.Label({ text: "Amount" }) }),
          ],
        });
        this.pageLabel = new m.Text({ text: "No output selected" });
        this.resultBox = new m.VBox({
          items: [
            new m.Title({ text: "Execution review", level: "H3" }),
            this.runList,
            new m.HBox({
              items: [
                this.runStatus,
                new m.Button({
                  text: "Cancel run",
                  type: "Transparent",
                  press: function () {
                    self.cancel();
                  },
                }),
                new m.Button({
                  text: "Retry snapshot",
                  type: "Transparent",
                  press: function () {
                    self.retry();
                  },
                }),
                new m.Button({
                  text: "View snapshot",
                  type: "Transparent",
                  press: function () {
                    self.showSnapshot();
                  },
                }),
              ],
            }),
            this.runDetails,
            this.runMessages,
            this.outputSelect,
            this.datasetSelect,
            this.table,
            new m.HBox({
              alignItems: "Center",
              items: [
                new m.Button({
                  icon: "sap-icon://navigation-left-arrow",
                  tooltip: "Previous page",
                  press: function () {
                    self.pageOffset = Math.max(0, self.pageOffset - 2);
                    self.preview();
                  },
                }),
                this.pageLabel,
                new m.Button({
                  icon: "sap-icon://navigation-right-arrow",
                  tooltip: "Next page",
                  press: function () {
                    if (self.pageOffset + 2 < self.total) {
                      self.pageOffset += 2;
                      self.preview();
                    }
                  },
                }),
              ],
            }),
          ],
        }).addStyleClass("results");
        var toolbar = new m.Toolbar({
          content: [
            new m.Button({
              text: "Save version",
              icon: "sap-icon://save",
              press: function () {
                self.save();
              },
            }),
            new m.Button({
              text: "Add cell",
              icon: "sap-icon://add",
              press: function () {
                self.addCell();
              },
            }),
            new m.Button({
              text: "Inputs",
              press: function () {
                self.editInputs();
              },
            }),
            new m.Button({
              text: "BPC model",
              press: function () { if (!self.notebook) { return; } self.chooseContext(function (ctx) {
                self.notebook.environment = ctx.environment; self.notebook.model = ctx.model;
                self.notebook.inputs.forEach(function (p) {
                  if (p.type === "member" || p.type === "range") { p.selected = []; p.resolved = []; p.hierarchy = ""; }
                });
                self.renderNotebook(); self.mark();
              }); },
            }),
            new m.Button({
              text: "Versions",
              icon: "sap-icon://history",
              press: function () {
                self.history();
              },
            }),
            new m.ToolbarSpacer(),
            new m.Button({
              text: "Run all",
              icon: "sap-icon://media-play",
              type: "Emphasized",
              press: function () {
                self.execute("all");
              },
            }),
          ],
        }).addStyleClass("notebookToolbar");
        var main = new m.VBox({
          width: "100%",
          items: [this.title, this.meta, toolbar, this.inputs, this.cells, this.resultBox],
        }).addStyleClass("main");
        main.setLayoutData(new m.FlexItemData({ growFactor: 1, baseSize: "0" }));
        var banner = new m.MessageStrip({
          text: Api.local
            ? "LOCAL SIMULATION · Demo calculations run in Node.js. Native ABAP compilation and SAP background jobs require SAP deployment."
            : "SAP DEV PROTOTYPE · Trusted authors only. Calculation outputs do not write live BPC data.",
          type: "Information",
          showIcon: true,
        }).addStyleClass("environmentBanner");
        var page = new m.Page({
          showHeader: false,
          content: [
            new m.Toolbar({
              content: [
                new sap.ui.core.Icon({ src: "sap-icon://document-text" }).addStyleClass("brandMark"),
                new m.Title({ text: "BPC Notebook" }),
                new m.Text({ text: "CALCULATION WORKSPACE" }),
                new m.ToolbarSpacer(),
                new m.ObjectStatus({
                  text: Api.local
                    ? "Local prototype"
                    : "SAP client " + (new URLSearchParams(location.search).get("sap-client") || "current"),
                  state: "None",
                }),
              ],
            }).addStyleClass("topbar"),
            banner,
            new m.HBox({ items: [this.sidebar, main] }).addStyleClass("workspace"),
          ],
        });
        Api.init()
          .then(function () {
            return self.refresh();
          })
          .catch(function (e) {
            self.error(e);
          });
        return new m.App({ pages: [page] }).addStyleClass("sapUiSizeCompact");
      },
      error: function (e) {
        MessageBox.error(e.message || String(e));
      },
      refresh: function () {
        var self = this;
        return Api.request("/notebooks").then(function (list) {
          self.list.removeAllItems();
          list.forEach(function (n) {
            self.list.addItem(
              new m.StandardListItem({
                tooltip: n.title,
                description: "Revision " + n.revision,
                icon: "sap-icon://document-text",
              }).setTitle(n.title).data("id", n.id),
            );
          });
        });
      },
      create: function (isDemo) {
        var self = this;
        if (this.dirty) {
          MessageBox.warning("Save the current notebook before creating another.");
          return;
        }
        var data = isDemo ? { demo: true } : { title: "Untitled calculation", inputs: [], cells: [] };
        function create(data) { return Api.request("/notebooks", "POST", data)
          .then(function (n) {
            self.resetReview();
            self.notebook = n;
            self.renderNotebook();
            self.refresh();
          })
          .catch(self.error.bind(self)); }
        if (isDemo && !Api.local) {
          this.chooseContext(function (ctx) { data.environment = ctx.environment; data.model = ctx.model; create(data); });
        } else { create(data); }
      },
      open: function (id) {
        var self = this;
        if (this.dirty) {
          MessageBox.warning("Save the current notebook before switching.");
          return;
        }
        Api.request("/notebook?id=" + encodeURIComponent(id))
          .then(function (n) {
            self.resetReview();
            self.notebook = n;
            self.runId = null;
            self.renderNotebook();
            self.loadRuns();
          })
          .catch(this.error.bind(this));
      },
      mark: function () {
        this.dirty = true;
        this.meta.setText("Unsaved changes · save before running · affected outputs are stale");
        this.cells.getItems().forEach(function (box) {
          var status = box.data("status");
          if (status) {
            status.setText("Stale · unsaved changes");
            status.setState("Warning");
          }
        });
      },
      resetReview: function () {
        clearTimeout(this.poll);
        this.runId = null;
        this.currentRun = null;
        this.pageOffset = 0;
        this.runList.removeAllItems();
        this.outputSelect.removeAllItems();
        this.table.removeAllItems();
        this.runMessages.removeAllItems();
        this.runDetails.setText("");
        this.runStatus.setText("No execution selected");
        this.pageLabel.setText("No output selected");
      },
      renderNotebook: function () {
        var self = this,
          n = this.notebook;
        this.dirty = false;
        this.title.setText(n.title);
        this.meta.setText(
          "Revision " + n.revision + " · " + n.cells.length + " cells · " + n.author + " · " + displayTime(n.savedAt),
        );
        this.inputs.removeAllItems();
        if (n.environment) {
          this.inputs.addItem(new m.VBox({items:[new m.Label({text:"BPC context"}),
            new m.Text({text:n.environment + " / " + n.model})]}));
        }
        n.inputs.forEach(function (p) {
          if (p.type === "member" || p.type === "range") { self.renderSelection(p); return; }
          self.inputs.addItem(
            new m.VBox({
              items: [
                new m.Label({ text: p.name + " · " + p.type }),
                new m.Input({
                  width: "170px",
                  change: function (e) {
                    var value = e.getSource().getValue();
                    p.value =
                      p.type === "number" ? Number(value) : p.type === "boolean" ? value === "true" : value;
                    self.mark();
                  },
                }).setValue(String(p.value)),
              ],
            }),
          );
        });
        this.cells.removeAllItems();
        n.cells.forEach(function (c, index) {
          var state = new m.ObjectStatus({
            text: c.output
              ? c.output.stale
                ? "Stale output"
                : c.output.rowCount + " rows · current"
              : "Not executed",
            state: c.output ? (c.output.stale ? "Warning" : "Success") : "None",
          }).addStyleClass("cellStatus");
          var box = new m.VBox({
            items: [
              new m.Toolbar({
                content: [
                  new m.Input({
                    value: c.title,
                    width: "52%",
                    change: function (e) {
                      c.title = e.getSource().getValue();
                      self.mark();
                    },
                  }).addStyleClass("cellTitle"),
                  state,
                  new m.ToolbarSpacer(),
                  new m.Button({
                    icon: "sap-icon://navigation-up-arrow",
                    tooltip: "Move cell up",
                    enabled: index > 0,
                    press: function () {
                      n.cells.splice(index, 1);
                      n.cells.splice(index - 1, 0, c);
                      self.renderNotebook();
                      self.mark();
                    },
                  }),
                  new m.Button({
                    icon: "sap-icon://navigation-down-arrow",
                    tooltip: "Move cell down",
                    enabled: index < n.cells.length - 1,
                    press: function () {
                      n.cells.splice(index, 1);
                      n.cells.splice(index + 1, 0, c);
                      self.renderNotebook();
                      self.mark();
                    },
                  }),
                ],
              }),
              new m.Text({ text: "Cell " + c.id + " · source v" + c.sourceVersion }).addStyleClass(
                "cellMeta",
              ),
              new m.TextArea({
                width: "100%",
                rows: Math.min(15, Math.max(5, c.source.split("\n").length)),
                liveChange: function (e) {
                  c.source = e.getSource().getValue();
                  self.mark();
                },
              }).setValue(c.source).addStyleClass("code"),
              new m.HBox({
                alignItems: "Center",
                wrap: "Wrap",
                items: [
                  new m.Label({ text: "Dependencies" }),
                  new m.Input({
                    value: c.dependencies.join(", "),
                    placeholder: "Earlier cell IDs, comma separated",
                    width: "230px",
                    change: function (e) {
                      c.dependencies = e
                        .getSource()
                        .getValue()
                        .split(",")
                        .map(function (v) {
                          return v.trim();
                        })
                        .filter(Boolean);
                      self.mark();
                    },
                  }),
                  new m.Button({
                    text: "Validate",
                    press: function () {
                      self.validate(c.id);
                    },
                  }),
                  new m.Button({
                    text: "Run cell",
                    icon: "sap-icon://media-play",
                    press: function () {
                      self.execute("one", c.id);
                    },
                  }),
                  new m.Button({
                    text: "Run through",
                    press: function () {
                      self.execute("through", c.id);
                    },
                  }),
                ],
              }).addStyleClass("cellActions"),
            ],
          })
            .addStyleClass("cell")
            .data("status", state);
          self.cells.addItem(box);
        });
      },
      save: function () {
        var self = this;
        if (!this.notebook) {
          return Promise.resolve();
        }
        var payload = JSON.parse(JSON.stringify(this.notebook));
        payload.expectedRevision = payload.revision;
        return Api.request("/notebook", "PUT", payload)
          .then(function (n) {
            self.notebook = n;
            self.renderNotebook();
            self.refresh();
            MessageToast.show("Immutable version saved");
          })
          .catch(function (e) {
            self.error(e);
            throw e;
          });
      },
      addCell: function () {
        if (!this.notebook) {
          return;
        }
        var n = this.notebook;
        n.cells.push({
          id: "cell_" + Date.now(),
          title: "New ABAP cell",
          source: "io->message( 'New cell' ).",
          dependencies: [],
          sourceVersion: 0,
        });
        this.renderNotebook();
        this.mark();
      },
      chooseContext: function (done) {
        var self = this;
        this.chooseMetadata({kind:"environments"}, false, [], function (ids) {
          var environment = ids[0];
          self.chooseMetadata({kind:"models", environment:environment}, false, [], function (models) {
            done({environment:environment, model:models[0]});
          });
        });
      },
      chooseMetadata: function (query, multiple, initial, done) {
        var self = this, selected = {}, generation = 0, offset = 0, searchTimer;
        (initial || []).forEach(function (id) { selected[id] = true; });
        var list = new m.List({includeItemInSelection:true, mode:multiple ? "MultiSelect" : "SingleSelectLeft",
          selectionChange:function (e) {
            var items = e.getParameter("listItems") || [e.getParameter("listItem")];
            if (!multiple) { selected = {}; }
            items.forEach(function (item) {
              var id = item.data("memberId");
              if (item.getSelected()) { selected[id] = true; } else { delete selected[id]; }
            });
          }});
        var search = new m.SearchField({placeholder:"Search ID or description", search:function () { load(false); },
          liveChange:function () { clearTimeout(searchTimer); searchTimer = setTimeout(function () { load(false); },300); }});
        var more = new m.Button({text:"Load more", visible:false, press:function () { load(true); }});
        var hierarchy = new m.Select({visible:query.kind === "members" && multiple,
          change:function () { query.hierarchy = hierarchy.getSelectedKey(); selected = {}; load(false); }});
        var dialog = new m.Dialog({title:query.dimension || "Select " + query.kind, contentWidth:"650px",
          contentHeight:"480px", content:[search, hierarchy, list, more],
          beginButton:new m.Button({text:"Apply selection", press:function () {
            var ids = Object.keys(selected);
            if (!multiple && ids.length !== 1) { MessageBox.warning("Select one item."); return; }
            done(ids, query.hierarchy || "", list.getItems()); dialog.close();
          }}),
          endButton:new m.Button({text:"Cancel",press:function () { dialog.close(); }}),
          afterClose:function () { generation++; clearTimeout(searchTimer); dialog.destroy(); }});
        function load(append) {
          var token = ++generation;
          if (!append) { offset = 0; }
          var data = Object.assign({},query,{search:search.getValue(),offset:offset});
          list.setBusy(true);
          Api.request("/metadata","POST",data).then(function (result) {
            if (token !== generation) { return; }
            if (multiple && query.kind === "members" && !query.hierarchy && result.hierarchies.length) {
              query.hierarchy = result.hierarchies[0]; load(false); return;
            }
            if (multiple && query.kind === "members" && !hierarchy.getItems().length) {
              result.hierarchies.forEach(function (id) { hierarchy.addItem(new sap.ui.core.Item({key:id,text:id})); });
              hierarchy.setSelectedKey(query.hierarchy);
            }
            if (!append) { list.removeAllItems(); }
            result.items.forEach(function (member) {
              var item = new m.StandardListItem({info:member.isNode ? "Node" : "", selected:!!selected[member.id]});
              item.setTitle(member.id); item.setDescription(member.description || member.id);
              item.data("memberId",member.id); item.data("description",member.description); list.addItem(item);
            });
            offset += result.items.length; more.setVisible(result.more); list.setBusy(false);
          }).catch(function (e) { if (token === generation) { list.setBusy(false); self.error(e); } });
        }
        dialog.open(); load(false);
      },
      renderSelection: function (p) {
        var self = this, n = this.notebook;
        p.selected = p.selected || []; p.resolved = p.resolved || [];
        var display = new m.Input({value:p.selected.join(", "), width:"260px", editable:true,
          showValueHelp:true, valueHelpOnly:true, placeholder:"Select " + p.dimension,
          valueHelpRequest:function () {
            self.chooseMetadata({kind:"members",environment:n.environment,model:n.model,
              dimension:p.dimension,hierarchy:p.hierarchy || ""},p.type === "range",p.selected,
              function (ids, hierarchy, items) {
                p.selected = ids; p.hierarchy = hierarchy; p.resolved = [];
                self.renderNotebook(); self.mark();
              });
          }});
        this.inputs.addItem(new m.VBox({items:[new m.Label({text:p.name + (p.required ? " *" : "") + " · " + p.dimension}),
          display, new m.Text({text:p.resolved.length ? p.resolved.length + " resolved member(s) · " + (p.hierarchy || "single member")
            : "Save to resolve and validate selection"}),
          new m.Button({text:"Clear",type:"Transparent",press:function () {
            p.selected = []; p.resolved = []; self.renderNotebook(); self.mark();
          }})]}));
      },
      editInputs: function () {
        var self = this;
        if (!this.notebook) {
          return;
        }
        var area = new m.TextArea({
          width: "100%",
          rows: 12,
        });
        // Set literal JSON after construction so UI5 does not interpret braces as bindings.
        area.setValue(JSON.stringify(this.notebook.inputs, null, 2));
        var dialog = new m.Dialog({
          title: "Typed inputs",
          contentWidth: "550px",
          content: [
            new m.Text({
              text: "JSON array: name, type (number/string/boolean/member/range). Scalars use value. BPC inputs use dimension, hierarchy, required and selected (IDs). Resolved IDs are backend-owned. Choose BPC model first.",
            }),
            new m.Label({text:"New dimension parameter"}),
            new m.Input({placeholder:"Parameter name (defaults to dimension ID)",change:function (e) {
              area.data("parameterName",e.getSource().getValue());
            }}),
            new m.Select({items:[new sap.ui.core.Item({key:"member",text:"Single member"}),
              new sap.ui.core.Item({key:"range",text:"Nodes / multiple base members"})],
              change:function (e) { area.data("parameterType",e.getSource().getSelectedKey()); }}),
            new m.CheckBox({text:"Required before running",selected:true,select:function (e) {
              area.data("parameterRequired",e.getParameter("selected"));
            }}),
            new m.Button({text:"Add dimension parameter",press:function () {
              if (!self.notebook.environment || !self.notebook.model) { MessageBox.warning("Choose BPC model first."); return; }
              self.chooseMetadata({kind:"dimensions",environment:self.notebook.environment,model:self.notebook.model},
                false,[],function (ids) {
                  var type = area.data("parameterType") || "member";
                  function append(hierarchy) {
                    try {
                      var definition = JSON.parse(area.getValue());
                      definition.push({name:area.data("parameterName") || ids[0],type:type,dimension:ids[0],
                        hierarchy:hierarchy,required:area.data("parameterRequired") !== false,selected:[]});
                      area.setValue(JSON.stringify(definition,null,2));
                    } catch (e) { self.error(e); }
                  }
                  if (type === "member") { append(""); return; }
                  Api.request("/metadata","POST",{kind:"members",environment:self.notebook.environment,
                    model:self.notebook.model,dimension:ids[0]}).then(function (result) {
                      append(result.hierarchies[0] || "");
                    }).catch(self.error.bind(self));
                });
            }}),
            area,
          ],
          beginButton: new m.Button({
            text: "Apply",
            press: function () {
              try {
                self.notebook.inputs = JSON.parse(area.getValue());
                if (!Array.isArray(self.notebook.inputs)) {
                  throw new Error("Expected an array");
                }
                self.renderNotebook();
                self.mark();
                dialog.close();
              } catch (e) {
                self.error(e);
              }
            },
          }),
          endButton: new m.Button({
            text: "Cancel",
            press: function () {
              dialog.close();
            },
          }),
          afterClose: function () {
            dialog.destroy();
          },
        });
        dialog.open();
      },
      validate: function (id) {
        var self = this;
        if (this.dirty) {
          MessageBox.warning("Save the source before validation.");
          return;
        }
        Api.request("/validate", "POST", { notebookId: this.notebook.id, cellId: id })
          .then(function (result) {
            MessageBox.information(
              result.diagnostics.length
                ? result.diagnostics
                    .map(function (d) {
                      return "Line " + d.line + ": " + d.message;
                    })
                    .join("\n")
                : result.native
                  ? "SAP temporary compilation succeeded."
                  : "Supported demonstration body. Native SAP compilation has not been performed.",
            );
          })
          .catch(self.error.bind(self));
      },
      execute: function (scope, id) {
        var self = this;
        if (this.submitting) {
          return;
        }
        if (!this.notebook) {
          return;
        }
        if (this.dirty) {
          MessageBox.warning("Save changes before executing a frozen snapshot.");
          return;
        }
        var payload = {
          notebookId: this.notebook.id,
          expectedRevision: this.notebook.revision,
          scope: scope,
          cellId: id || "",
          idempotencyKey: Api.key(),
        };
        if (
          this.pendingSubmission &&
          this.pendingSubmission.notebookId === payload.notebookId &&
          this.pendingSubmission.expectedRevision === payload.expectedRevision &&
          this.pendingSubmission.scope === scope &&
          this.pendingSubmission.cellId === payload.cellId
        ) {
          payload = this.pendingSubmission;
        }
        this.pendingSubmission = payload;
        this.submitting = true;
        Api.request("/runs", "POST", payload)
          .then(function (run) {
            self.submitting = false;
            self.pendingSubmission = null;
            self.runId = run.id;
            self.loadRuns().then(function () {
              self.inspect(run.id);
            });
          })
          .catch(function (e) {
            self.submitting = false;
            self.error(e);
          });
      },
      loadRuns: function () {
        var self = this;
        if (!this.notebook) {
          return Promise.resolve();
        }
        return Api.request("/runs?notebookId=" + encodeURIComponent(this.notebook.id)).then(function (runs) {
          self.runList.removeAllItems();
          runs.forEach(function (r) {
            self.runList.addItem(
              new sap.ui.core.Item({ key: r.id, text: displayTime(r.createdAt) + " · " + r.state + " · " + r.scope }),
            );
          });
          if (self.runId) {
            self.runList.setSelectedKey(self.runId);
          }
        });
      },
      inspect: function (id) {
        var self = this;
        if (!id) {
          return;
        }
        if (this.runId !== id) {
          this.pageOffset = 0;
        }
        this.runId = id;
        clearTimeout(this.poll);
        Api.request("/run?id=" + encodeURIComponent(id))
          .then(function (r) {
            if (self.runId !== id) {
              return;
            }
            self.currentRun = r;
            self.runStatus.setText(r.state + " · " + Math.round(r.progress * 100) + "%");
            self.runStatus.setState(
              r.state === "failed" ? "Error" : r.state === "succeeded" ? "Success" : "None",
            );
            self.runDetails.setText(
              "Frozen revision " +
                r.snapshot.revision +
                " · " +
                r.jobName +
                " / " +
                r.jobId +
                " · " +
                (r.durationMs || 0) +
                " ms",
            );
            self.runMessages.removeAllItems();
            r.messages.forEach(function (v) {
              self.runMessages.addItem(new m.Text({ text: v.cellId + ": " + v.text }));
            });
            if (r.error) {
              self.runMessages.addItem(
                new m.MessageStrip({ text: r.error.code + ": " + r.error.message, type: "Error" }),
              );
            }
            var selected = self.outputSelect.getSelectedKey();
            self.outputSelect.removeAllItems();
            r.results.forEach(function (o) {
              self.outputSelect.addItem(
                new sap.ui.core.Item({
                  key: o.cellId,
                  text: o.cellId + " · " + o.rowCount + " rows · " + o.durationMs + " ms",
                }),
              );
            });
            self.outputSelect.setSelectedKey(
              r.results.some(function (o) {
                return o.cellId === selected;
              })
                ? selected
                : r.results.length
                  ? r.results[0].cellId
                  : "",
            );
            if (r.results.length) {
              self.preview();
            } else {
              self.table.removeAllItems();
              self.pageLabel.setText("No persisted output");
            }
            if (["queued", "running"].indexOf(r.state) >= 0) {
              self.poll = setTimeout(function () {
                self.inspect(id);
              }, 1000);
            } else {
              self.loadRuns();
              if (!self.dirty) {
                Api.request("/notebook?id=" + self.notebook.id).then(function (n) {
                  if (!self.notebook || self.notebook.id !== n.id || self.dirty) {
                    return;
                  }
                  self.notebook = n;
                  self.renderNotebook();
                });
              }
            }
          })
          .catch(self.error.bind(self));
      },
      cancel: function () {
        var self = this;
        if (this.runId) {
          Api.request("/cancel", "POST", { id: this.runId })
            .then(function () {
              self.inspect(self.runId);
            })
            .catch(self.error.bind(self));
        }
      },
      retry: function () {
        var self = this;
        if (!this.runId || this.submitting) {
          return;
        }
        this.submitting = true;
        Api.request("/retry", "POST", { id: this.runId, idempotencyKey: Api.key() })
          .then(function (run) {
            self.submitting = false;
            self.runId = run.id;
            self.pageOffset = 0;
            self.loadRuns().then(function () {
              self.inspect(run.id);
            });
          })
          .catch(function (e) {
            self.submitting = false;
            self.error(e);
          });
      },
      showSnapshot: function () {
        if (!this.currentRun) {
          return;
        }
        var r = this.currentRun;
        this.showDocument("Frozen execution snapshot", {
          runId: r.id,
          checksum: r.checksum,
          snapshot: r.snapshot,
          dependencyBindings: r.frozenBindings || r.bindings,
        });
      },
      showDocument: function (title, data) {
        var area = new m.TextArea({
          editable: false,
          width: "100%",
          rows: 24,
        });
        // Set literal JSON after construction so UI5 does not interpret braces as a binding.
        area.setValue(JSON.stringify(data, null, 2));
        var dialog = new m.Dialog({
          title: title,
          contentWidth: "820px",
          content: [area],
          endButton: new m.Button({
            text: "Close",
            press: function () {
              dialog.close();
            },
          }),
          afterClose: function () {
            dialog.destroy();
          },
        });
        dialog.open();
      },
      preview: function () {
        var self = this,
          id = this.outputSelect.getSelectedKey();
        if (!id || !this.runId) {
          return;
        }
        Api.request(
          "/output?runId=" +
            encodeURIComponent(this.runId) +
            "&cellId=" +
            encodeURIComponent(id) +
            "&revision=1&offset=" +
            this.pageOffset +
            "&limit=2&table=" + encodeURIComponent(this.tableName || ""),
        )
          .then(function (page) {
            self.total = page.total;
            self.table.removeAllItems();
            self.table.destroyColumns();
            (page.schema || []).forEach(function(column) {
              self.table.addColumn(new m.Column({header: new m.Label({text: column.name})}));
            });
            self.datasetSelect.removeAllItems();
            self.datasetSelect.setVisible(!!(page.tables && page.tables.length));
            (page.tables || []).forEach(function(t) {
              self.datasetSelect.addItem(new sap.ui.core.Item({key:t.name,text:t.name + " · " + t.totalCount + " rows"}));
            });
            self.tableName = page.tableName || "";
            self.datasetSelect.setSelectedKey(self.tableName);
            page.rows.forEach(function (row) {
              self.table.addItem(new m.ColumnListItem({cells: (page.schema || []).map(function(column,index) {
                // Keep exact decimal text and member IDs; avoid JavaScript numeric rounding.
                var value = row.values ? row.values[index] : row[column.name];
                return new m.Text({text: value == null ? "" : String(value)});
              })}));
            });
            self.pageLabel.setText(
              page.offset +
                1 +
                "–" +
                Math.min(page.offset + page.limit, page.total) +
                " of " +
                page.total +
                " · output revision " +
                page.revision + (page.truncated ? " · preview of " + page.sourceTotal + " source rows" : ""),
            );
          })
          .catch(self.error.bind(self));
      },
      history: function () {
        var self = this;
        if (!this.notebook) {
          return;
        }
        Api.request("/versions?id=" + this.notebook.id)
          .then(function (versions) {
            var list = new m.List();
            versions
              .slice()
              .reverse()
              .forEach(function (v) {
                list.addItem(
                  new m.StandardListItem({
                    title: "Revision " + v.revision + " · " + v.author,
                    description: v.savedAt,
                    type: "Active",
                    press: function () {
                      self.showDocument("Immutable revision " + v.revision, v);
                    },
                  }),
                );
              });
            var dialog = new m.Dialog({
              title: "Source and input history",
              contentWidth: "650px",
              content: [list],
              endButton: new m.Button({
                text: "Close",
                press: function () {
                  dialog.close();
                },
              }),
              afterClose: function () {
                dialog.destroy();
              },
            });
            dialog.open();
          })
          .catch(self.error.bind(self));
      },
      exit: function () {
        clearTimeout(this.poll);
      },
    });
  },
);
